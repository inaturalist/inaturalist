require "rubygems"
require "optimist"

opts = Optimist::options do
    banner <<-EOS
Resurrect observations

Usage:
  rails runner tools/resurrect_observations.rb [ -u USER_ID, -o OBSERVATION_ID ]

Options:
EOS
  opt :user, "User whose observations to resurrect", :short => "-u", :type => :string
  opt :observation, "Observation ID(s) to resurrect", :short => "-o", :type => :string
  opt :observation_ids_file, "File containing obs ids, one per line", short: "-f", type: :string
  opt :observed_on, "Observed date to resurrect observations from, format: YYYY-MM-DD", :short => "-d", :type => :string
  opt :created_on, "Created date to resurrect observations from, format: YYYY-MM-DD", :short => "-c", :type => :string
  opt :dbname, "Database to connect export from", short: "-n", type: :string, default: ActiveRecord::Base.connection.current_database
  opt :skip, "Models to skip", short: "-s", type: :string, multi: true
  opt :from_user_resurrection, "Restoring observations of resurrected user", :type => :boolean, :short => "-r"
end

OPTS = opts

unless OPTS.user || OPTS.observation || OPTS.observed_on || OPTS.created_on || OPTS.observation_ids_file
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

if OPTS.observation || OPTS.observation_ids_file
  observation_ids = if OPTS.observation_ids_file
    ids = []
    CSV.foreach( OPTS.observation_ids_file ) do |row|
      ids << row[0].to_i unless row[0].to_i == 0
    end
    ids.uniq
  elsif OPTS.observation
    OPTS.observation.split( "," )
  end
  if ActiveRecord::Base.connection.current_database != OPTS.dbname
    # if we're trying to extract data from a separate database AND we're specifying obs IDs, we need to look for them in that database
    Observation.establish_connection( ActiveRecord::Base.connection_config.merge( database: OPTS.dbname ) )
    begin
      Observation.first
    rescue PG::ConnectionBad
      Observation.establish_connection( ActiveRecord::Base.connection_config.merge(
        database: OPTS.dbname,
        host: nil,
        password: nil
      ) )
    end
  end
  @observations = Observation.where( id: observation_ids )
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

es_cmds = []
if @where[0].to_s =~ /id IN \(/
  es_cmds << @observations.in_groups_of( 500 ).map { |obs|
    new_where = ["observations.id IN (#{obs.compact.map(&:id).join( "," )})"] + @where[1..-1]
    "RAILS_ENV=production bundle exec rails r \"Observation.elastic_index!( scope: Observation.where( '#{new_where.join( " AND " )}' ) )\""
  }.join( " && \\\n" )
  es_cmds << @observations.in_groups_of( 500 ).map { |obs|
    new_where = ["observations.id IN (#{obs.compact.map(&:id).join( "," )})"] + @where[1..-1]
    "RAILS_ENV=production bundle exec rails r \"Identification.elastic_index!( scope: Identification.joins(:observation).where( '#{new_where.join( " AND " )}' ) )\""
  }.join( " && \\\n" )
else
  es_cmds << "RAILS_ENV=production bundle exec rails r \"Observation.elastic_index!( scope: Observation.where( '#{@where.join( " AND " )}' ) )\""
  es_cmds << "RAILS_ENV=production bundle exec rails r \"Identification.elastic_index!( scope: Identification.joins(:observation).where( '#{@where.join( " AND " )}' ) )\""
end

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
  next unless [:destroy, :delete_all].include?( reflection.options[:dependent] )
  next if k.to_s == "observation_photos"
  next if k.to_s == "model_attribute_changes"
  puts "Exporting #{k}..."
  fname = "resurrect_#{session_id}-#{reflection.table_name}.csv"
  unless table_names.include?(reflection.table_name)
    system "test #{fname} || rm #{fname}"
  end
  join_condition = "#{reflection.table_name}.#{reflection.foreign_key} = observations.id"
  # if the reflection is polymorphic, we need to add an additional condition for the type column
  if %w( comments taggings tag_taggings votes_for flags annotations ).include?( k.to_s ) && reflection.options[:as]
    join_condition += " AND #{reflection.table_name}.#{reflection.options[:as]}_type = 'Observation'"
  end
  if OPTS.from_user_resurrection && @user
    if ["comments", "quality_metrics"].include?( reflection.table_name )
      join_condition += " AND #{reflection.table_name}.user_id != #{@user.id}"
    elsif reflection.table_name == "votes"
      join_condition += " AND #{reflection.table_name}.voter_id != #{@user.id}"
    end
 end
  sql = <<-SQL
    SELECT DISTINCT
      #{column_names.map{|cn| "#{reflection.table_name}.#{cn}"}.join( ", " )}
    FROM #{reflection.table_name}
      JOIN observations ON #{join_condition}
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

  puts "Exporting from photo_metadata..."
  fname = "resurrect_#{session_id}-photo_metadata.csv"
  column_names = PhotoMetadata.column_names
  sql = <<-SQL
    SELECT DISTINCT
      #{column_names.map{|cn| "photo_metadata.#{cn}"}.join( ", " )}
    FROM photo_metadata
      JOIN photos ON photo_metadata.photo_id = photos.id
      JOIN observation_photos ON observation_photos.photo_id = photos.id
      JOIN observations ON observations.id = observation_photos.observation_id
    WHERE #{@where.join(' AND ')}
  SQL
  cmd = "psql #{OPTS.dbname} -c \"COPY (#{sql}) TO STDOUT WITH CSV\" > #{fname}"
  puts "\t#{cmd}"
  system cmd
  resurrection_cmds << "psql #{OPTS.dbname} -c \"\\COPY photo_metadata (#{column_names.join( ", " )}) FROM '#{fname}' WITH CSV\""
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
#{es_cmds.join("\n")}
EOT
if @user
  puts <<-EOT
bundle exec rails r "User.update_identifications_counter_cache(#{@user.id})"
bundle exec rails r "User.update_observations_counter_cache(#{@user.id})"
bundle exec rails r "User.elastic_index!( ids: [#{@user.id}])"
  EOT
end

if OPTS.from_user_resurrection && @user
  puts
  puts "Indexing commands for a resurrected users data"
  puts "  Observation.elastic_index!( scope: Observation.where( user_id: #{@user.id} ) )"
  puts "  Observation.elastic_index!( scope: Observation.joins( :identifications ).where( \"identifications.user_id=#{@user.id}\" ) )"
  puts "  User.find( #{@user.id} ).elastic_index!"
end
