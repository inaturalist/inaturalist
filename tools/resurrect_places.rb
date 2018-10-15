require "rubygems"
require "optimist"

opts = Optimist::options do
    banner <<-EOS
Resurrect places

Usage:
  rails runner tools/resurrect_places.rb PLACE_ID

Options:
EOS
  opt :debug, "Print debug statements", :short => "-d", :type => :boolean
end

OPTS = opts

unless ARGV[0]
  puts "You must specify a place ID"
  exit(0)
end

session_id = Digest::MD5.hexdigest(OPTS.to_s)
table_name = 'places'
table_names = []
resurrection_cmds = []
update_statements = []

@where = ["#{table_name}.id = #{ARGV[0]}"]

system "rm -rf resurrect_#{session_id}*"

puts "Exporting from #{table_name}..."
fname = "resurrect_#{session_id}-#{table_name}.csv"
cmd = "psql inaturalist_production -c \"COPY (SELECT * FROM #{table_name} WHERE #{@where.join(' AND ')}) TO STDOUT WITH CSV\" > #{fname}"
puts "\t#{cmd}"
system cmd
resurrection_cmds << "psql inaturalist_production -c \"\\copy #{table_name} FROM '#{fname}' WITH CSV\""

update_statements = []

has_many_reflections = Place.reflections.select{|k,v| v.macro == :has_many || k == 'place_geometry'}
has_many_reflections.each do |k, reflection|
  if OPTS.debug
    puts "Examining reflection for #{k}"
    puts "reflection.klass.column_names.include?(reflection.foreign_key): #{reflection.klass.column_names.include?(reflection.foreign_key)}"
    puts "reflection.options[:dependent]: #{reflection.options[:dependent]}"
    puts "table_names.include?(reflection.table_name): #{table_names.include?(reflection.table_name)}"
  end
  # Avoid those pesky :through relats
  next unless reflection.klass.column_names.include?(reflection.foreign_key)
  if reflection.options[:dependent] != :destroy && k != 'listed_taxa'
    next
  end
  puts "Exporting #{k}..."
  fname = "resurrect_#{session_id}-#{reflection.table_name}.csv"
  unless table_names.include?(reflection.table_name)
    system "test #{fname} || rm #{fname}"
  end
  sql = <<-SQL
    SELECT DISTINCT #{reflection.table_name}.*
    FROM #{reflection.table_name}
      JOIN #{table_name} ON #{reflection.table_name}.#{reflection.foreign_key} = #{table_name}.id
    WHERE #{@where.join(' AND ')}
  SQL
  cmd = "psql inaturalist_production -c \"COPY (#{sql}) TO STDOUT WITH CSV\" > #{fname}"
  system cmd
  puts "\t#{cmd}"
  resurrection_cmds << "psql inaturalist_production -c \"\\copy #{reflection.table_name} FROM '#{fname}' WITH CSV\""
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
bundle exec rails r "p = Place.find(#{ARGV[0]}); p.name_will_change!; p.slug = nil; p.save!"
EOT
puts
puts "Keep in mind that this will not resurrect a places ancestors, so you may still have integrity issues with the ancestry."
puts
