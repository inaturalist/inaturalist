user_id = ARGV[0]
table_names = []
resurrection_cmds = []

puts
puts <<-EOT
This script assumes you're currently connected to a database that has the data
you want to export, so if it bails b/c it can't find your user, that's
probably why.
EOT
puts

system "rm resurrect_#{user_id}*"

puts "Exporting from users..."
fname = "resurrect_#{user_id}-users.csv"
cmd = "psql inaturalist_production -c \"COPY (SELECT * FROM users WHERE id = #{user_id}) TO STDOUT WITH CSV\" > #{fname}"
puts "\t#{cmd}"
system cmd
resurrection_cmds << "psql inaturalist_production -c \"\\copy users FROM '#{fname}' WITH CSV\""

puts "Exporting from photos (except LocalPhotos, which are gone)..."
fname = "resurrect_#{user_id}-photos.csv"
cmd = "psql inaturalist_production -c \"COPY (SELECT * FROM photos WHERE user_id = #{user_id} AND type != 'LocalPhoto') TO STDOUT WITH CSV\" > #{fname}"
puts "\t#{cmd}"
system cmd
resurrection_cmds << "psql inaturalist_production -c \"\\copy photos FROM '#{fname}' WITH CSV\""

update_statements = []

has_many_reflections = User.reflections.select{|k,v| v.macro == :has_many}
has_many_reflections.each do |k, reflection|
  # Avoid those pesky :through relats
  next unless reflection.klass.column_names.include?(reflection.foreign_key)
  next unless reflection.options[:dependent] == :destroy
  next if k.to_s == "photos"
  puts "Exporting #{k}..."
  fname = "resurrect_#{user_id}-#{reflection.table_name}.csv"
  unless table_names.include?(reflection.table_name)
    system "test #{fname} || rm #{fname}"
  end
  cmd = "psql inaturalist_production -c \"COPY (SELECT * FROM #{reflection.table_name} WHERE #{reflection.foreign_key} = #{user_id}) TO STDOUT WITH CSV\" >> #{fname}"
  system cmd
  puts "\t#{cmd}"
  resurrection_cmds << "psql inaturalist_production -c \"\\copy #{reflection.table_name} FROM '#{fname}' WITH CSV\""
end

puts "Exporting from observation_photos..."
fname = "resurrect_#{user_id}-observation_photos.csv"
sql = <<-SQL
SELECT observation_photos.* 
FROM 
  observation_photos 
    JOIN observations ON observations.id = observation_photos.observation_id 
    JOIN photos ON photos.id = observation_photos.photo_id 
WHERE
  observations.user_id = #{user_id} 
  AND photos.type != 'LocalPhoto'
SQL
cmd = "psql inaturalist_production -c \"COPY (#{sql.gsub("\n", ' ')}) TO STDOUT WITH CSV\" > #{fname}"
puts "\t#{cmd}"
system cmd
resurrection_cmds << "psql inaturalist_production -c \"\\copy observation_photos FROM '#{fname}' WITH CSV\""

puts "Exporting from project_observations..."
fname = "resurrect_#{user_id}-project_observations.csv"
sql = <<-SQL
SELECT project_observations.* 
FROM 
  project_observations 
    JOIN observations ON observations.id = project_observations.observation_id
WHERE
  observations.user_id = #{user_id}
SQL
cmd = "psql inaturalist_production -c \"COPY (#{sql.gsub("\n", ' ')}) TO STDOUT WITH CSV\" > #{fname}"
puts "\t#{cmd}"
system cmd
resurrection_cmds << "psql inaturalist_production -c \"\\copy project_observations FROM '#{fname}' WITH CSV\""

puts "Exporting from observation_field_values..."
fname = "resurrect_#{user_id}-observation_field_values.csv"
sql = <<-SQL
SELECT observation_field_values.* 
FROM 
  observation_field_values 
    JOIN observations ON observations.id = observation_field_values.observation_id
WHERE
  observations.user_id = #{user_id}
SQL
cmd = "psql inaturalist_production -c \"COPY (#{sql.gsub("\n", ' ')}) TO STDOUT WITH CSV\" > #{fname}"
puts "\t#{cmd}"
system cmd
resurrection_cmds << "psql inaturalist_production -c \"\\copy observation_field_values FROM '#{fname}' WITH CSV\""

puts "Exporting from listed_taxa..."
fname = "resurrect_#{user_id}-listed_taxa.csv"
sql = <<-SQL
SELECT listed_taxa.* 
FROM 
  listed_taxa 
    JOIN lists ON lists.id = listed_taxa.list_id
WHERE
  lists.user_id = #{user_id}
SQL
cmd = "psql inaturalist_production -c \"COPY (#{sql.gsub("\n", ' ')}) TO STDOUT WITH CSV\" > #{fname}"
puts "\t#{cmd}"
system cmd
resurrection_cmds << "psql inaturalist_production -c \"\\copy listed_taxa FROM '#{fname}' WITH CSV\""

# TODO restore subscriptions to user
# TODO restore identifications on user's observations

cmd = "tar cvzf resurrect_#{user_id}.tgz resurrect_#{user_id}-*"
puts "Zipping it all up..."
puts "\t#{cmd}"
system cmd

cmd = "rm resurrect_#{user_id}-*"
puts "Cleaning up..."
puts "\t#{cmd}"
system cmd

puts
puts "Now run these commands (or something like them, depending on your setup):"
puts
puts <<-EOT
scp resurrect_#{user_id}.tgz inaturalist@taricha:deployment/production/current/
ssh -t inaturalist@taricha "cd deployment/production/current ; bash"
tar xzvf resurrect_#{user_id}.tgz
#{resurrection_cmds.uniq.join("\n")}
EOT
