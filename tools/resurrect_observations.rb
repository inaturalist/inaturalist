require 'rubygems'
require 'trollop'

opts = Trollop::options do
    banner <<-EOS
Resurrect observations

Usage:
  rails runner tools/resurrect_observations.rb [ -u USER_ID, -o OBSERVATION_ID ]

Options:
EOS
  opt :user, "User whose observations to resurrect", :short => "-u", :type => :string
  opt :observation, "Observation ID(s) to resurrect", :short => "-o", :type => :string
  opt :observed_on, "Observed date to resurrect observations from, format: YYYY-MM-DD", :short => "-d", :type => :string
  opt :created_on, "Created date to resurrect observations from, format: YYYY-MM-DD", :short => "-c", :type => :string
  opt :dbname, "Database to connect export from", short: "-n", type: :string, default: ActiveRecord::Base.connection.current_database
  opt :skip, "Models to skip", short: "-s", type: :string, multi: true
end

OPTS = opts

unless OPTS.user || OPTS.observation || OPTS.observed_on || OPTS.created_on
  puts "You must specify a user, an observation, or a date"
  exit(0)
end

session_id = Digest::MD5.hexdigest(OPTS.to_s)
table_names = []
resurrection_cmds = []
update_statements = []

@where = []
if OPTS.user
  if @user = User.find_by_id(OPTS.user) || User.find_by_login(OPTS.user)
    @where << "observations.user_id = #{@user.id}"
  else
    puts "Couldn't find user matching '#{OPTS.user}'"
    exit(0)
  end
end

if OPTS.observation
  @observations = Observation.where(id: OPTS.observation.split(","))
  unless @observations.blank?
    @where << "observations.id IN (#{@observations.map(&:id).join(',')})"
  else
    puts "Couldn't find observations matching '#{OPTS.observation}'"
    exit(0)
  end
end

if OPTS.observed_on
  if @observed_on = Date.parse(OPTS.observed_on)
    @where += ["observed_on = '#{@observed_on}'"]
  else
    puts "Couldn't parse date from '#{OPTS.observed_on}'"
    exit(0)
  end
end

if OPTS.created_on
  if @created_on = Date.parse(OPTS.created_on)
    @where += ["observations.created_at::DATE = '#{@created_on}'"]
  else
    puts "Couldn't parse date from '#{OPTS.created_on}'"
    exit(0)
  end
end

es_cmd = "RAILS_ENV=production bundle exec rails r \"Observation.elastic_index!( scope: Observation.where( '#{@where.join( " AND " )}' ) )\""

system "rm -rf resurrect_#{session_id}*"

unless OPTS.skip.include?( "Observation" )
  puts "Exporting from observations..."
  fname = "resurrect_#{session_id}-observations.csv"
  column_names = Observation.column_names
  cmd = "psql #{OPTS.dbname} -c \"COPY (SELECT #{column_names.join( ", " )} FROM observations WHERE #{@where.join(' AND ')}) TO STDOUT WITH CSV\" > #{fname}"
  puts "\t#{cmd}"
  system cmd
  resurrection_cmds << "psql #{OPTS.dbname} -c \"\\COPY observations (#{column_names.join( ", " )}) FROM '#{fname}' WITH CSV\""
end

update_statements = []

has_many_reflections = Observation.reflections.select{|k,v| v.macro == :has_many}
has_many_reflections.each do |k, reflection|
  next if OPTS.skip.include?( reflection.klass.to_s )
  # Avoid those pesky :through relats
  column_names = reflection.klass.column_names
  next unless column_names.include?(reflection.foreign_key)
  next unless reflection.options[:dependent] == :destroy
  next if k.to_s == "observation_photos"
  next if k.to_s == "model_attribute_changes"
  puts "Exporting #{k}..."
  fname = "resurrect_#{session_id}-#{reflection.table_name}.csv"
  unless table_names.include?(reflection.table_name)
    system "test #{fname} || rm #{fname}"
  end
  sql = <<-SQL
    SELECT DISTINCT
      #{column_names.map{|cn| "#{reflection.table_name}.#{cn}"}.join( ", " )}
    FROM #{reflection.table_name}
      JOIN observations ON #{reflection.table_name}.#{reflection.foreign_key} = observations.id
    WHERE #{@where.join(' AND ')}
  SQL
  cmd = "psql #{OPTS.dbname} -c \"COPY (#{sql}) TO STDOUT WITH CSV\" > #{fname}"
  system cmd
  puts "\t#{cmd}"
  resurrection_cmds << "psql #{OPTS.dbname} -c \"\\COPY #{reflection.table_name} (#{column_names.join( ", " )}) FROM '#{fname}' WITH CSV\""
end

unless OPTS.skip.include?( "Photo" )
  puts "Exporting from photos..."
  fname = "resurrect_#{session_id}-photos.csv"
  column_names = Photo.column_names
  sql = <<-SQL
    SELECT DISTINCT
      #{column_names.map{|cn| "photos.#{cn}"}.join( ", " )}
    FROM photos
      JOIN observation_photos ON observation_photos.photo_id = photos.id
      JOIN observations ON observations.id = observation_photos.observation_id
    WHERE #{@where.join(' AND ')}
  SQL
  cmd = "psql #{OPTS.dbname} -c \"COPY (#{sql}) TO STDOUT WITH CSV\" > #{fname}"
  puts "\t#{cmd}"
  system cmd
  resurrection_cmds << "psql #{OPTS.dbname} -c \"\\COPY photos (#{column_names.join( ", " )}) FROM '#{fname}' WITH CSV\""
end

unless OPTS.skip.include?( "ObservationPhoto" )
  puts "Exporting from observation_photos..."
  fname = "resurrect_#{session_id}-observation_photos.csv"
  column_names = ObservationPhoto.column_names
  sql = <<-SQL
    SELECT DISTINCT
      #{column_names.map{|cn| "observation_photos.#{cn}"}.join( ", " )}
    FROM observation_photos
      JOIN photos ON photos.id = observation_photos.photo_id
      JOIN observations ON observations.id = observation_photos.observation_id
    WHERE #{@where.join(' AND ')}
  SQL
  cmd = "psql #{OPTS.dbname} -c \"COPY (#{sql}) TO STDOUT WITH CSV\" > #{fname}"
  puts "\t#{cmd}"
  system cmd
  resurrection_cmds << "psql #{OPTS.dbname} -c \"\\COPY observation_photos (#{column_names.join( ", " )}) FROM '#{fname}' WITH CSV\""
end

unless OPTS.skip.include?( "Sound" )
  puts "Exporting from sounds..."
  fname = "resurrect_#{session_id}-sounds.csv"
  column_names = Sound.column_names
  sql = <<-SQL
    SELECT DISTINCT
      #{column_names.map{|cn| "sounds.#{cn}"}.join( ", " )}
    FROM sounds
      JOIN observation_sounds ON observation_sounds.sound_id = sounds.id
      JOIN observations ON observations.id = observation_sounds.observation_id
    WHERE #{@where.join(' AND ')}
  SQL
  cmd = "psql #{OPTS.dbname} -c \"COPY (#{sql}) TO STDOUT WITH CSV\" > #{fname}"
  puts "\t#{cmd}"
  system cmd
  resurrection_cmds << "psql #{OPTS.dbname} -c \"\\COPY sounds (#{column_names.join( ", " )}) FROM '#{fname}' WITH CSV\""
end

cmd = "tar cvzf resurrect_#{session_id}.tgz resurrect_#{session_id}-*"
puts "Zipping it all up..."
puts "\t#{cmd}"
system cmd

cmd = "rm resurrect_#{session_id}-*"
puts "Cleaning up..."
puts "\t#{cmd}"
system cmd

puts
puts "Now run these commands (or something like them, depending on your setup):"
puts
puts <<-EOT
scp resurrect_#{session_id}.tgz inaturalist@taricha:deployment/production/current/
ssh -t inaturalist@taricha "cd deployment/production/current ; bash"
tar xzvf resurrect_#{session_id}.tgz
#{resurrection_cmds.uniq.join("\n")}
source /usr/local/rvm/scripts/rvm 
#{es_cmd}
EOT
