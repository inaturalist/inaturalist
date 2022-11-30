taxon_id = ARGV[0]
taxon = Taxon.find_by_id(taxon_id)
table_names = []
resurrection_cmds = []
dbname = ActiveRecord::Base.connection.current_database

puts
puts <<-EOT
This script assumes you're currently connected to a database that has the data
you want to export, so if it bails b/c it can't find your taxon, that's
probably why.
EOT
puts

system "rm resurrect_#{taxon_id}*"

puts "Exporting from taxa..."
fname = "resurrect_#{taxon_id}-taxa.csv"
cmd = "psql #{dbname} -c \"COPY (SELECT * FROM taxa WHERE id = #{taxon_id}) TO STDOUT WITH CSV\" > #{fname}"
puts "\t#{cmd}"
system cmd
resurrection_cmds << "psql #{dbname} -c \"\\copy taxa FROM '#{fname}' WITH CSV\""

has_many_reflections = Taxon.reflections.select{|k,v| v.macro == :has_many}
has_many_reflections.each do |k, reflection|
  # Avoid those pesky :through relats
  next unless reflection.klass.column_names.include?(reflection.foreign_key)
  if reflection.options[:dependent] == :nullify
    associate_ids = taxon.send("#{k.to_s.singularize}_ids").join(',')
    unless associate_ids.blank?
      fname = "resurrect_#{taxon_id}-#{reflection.table_name}.sql"
      File.open( fname, "w" ) do |f|
        f << "UPDATE #{reflection.table_name} SET #{reflection.foreign_key} = #{taxon_id} WHERE id IN (#{associate_ids})"
      end
      resurrection_cmds << "psql #{dbname} < #{fname}"
    end
  end
  next unless reflection.options[:dependent] == :destroy
  next if k.to_s == "photos"
  next if k.to_s == "taxon_photos"
  puts "Exporting #{k}..."
  fname = "resurrect_#{taxon_id}-#{reflection.table_name}.csv"
  unless table_names.include?(reflection.table_name)
    system "test #{fname} || rm #{fname}"
  end
  cmd = "psql #{dbname} -c \"COPY (SELECT * FROM #{reflection.table_name} WHERE #{reflection.foreign_key} = #{taxon_id}) TO STDOUT WITH CSV\" >> #{fname}"
  system cmd
  puts "\t#{cmd}"
  resurrection_cmds << "psql #{dbname} -c \"\\copy #{reflection.table_name} FROM '#{fname}' WITH CSV\""
end

puts "Exporting from taxon_photos..."
fname = "resurrect_#{taxon_id}-taxon_photos.csv"
sql = <<-SQL
SELECT taxon_photos.* 
FROM 
  taxon_photos 
    JOIN taxa ON taxa.id = taxon_photos.taxon_id 
    JOIN photos ON photos.id = taxon_photos.photo_id 
WHERE
  taxa.id = #{taxon_id} 
  AND photos.type != 'LocalPhoto'
SQL
cmd = "psql #{dbname} -c \"COPY (#{sql.gsub("\n", ' ')}) TO STDOUT WITH CSV\" > #{fname}"
puts "\t#{cmd}"
system cmd
resurrection_cmds << "psql #{dbname} -c \"\\copy taxon_photos FROM '#{fname}' WITH CSV\""

puts "Exporting from photos..."
fname = "resurrect_#{taxon_id}-photos.csv"
sql = <<-SQL
SELECT photos.* 
FROM 
  photos 
    JOIN taxon_photos ON photos.id = taxon_photos.photo_id 
    JOIN taxa ON taxa.id = taxon_photos.taxon_id 
WHERE
  taxa.id = #{taxon_id} 
  AND photos.type != 'LocalPhoto'
SQL
cmd = "psql #{dbname} -c \"COPY (#{sql.gsub("\n", ' ')}) TO STDOUT WITH CSV\" > #{fname}"
puts "\t#{cmd}"
system cmd
resurrection_cmds << "psql #{dbname} -c \"\\copy photos FROM '#{fname}' WITH CSV\""

# Note that we don't have to deal with guide taxon associates b/c the guide taxa
# weren't deleted, just nulified, so their associates should still be there.

resurrection_cmds << "bundle exec rails r 'Taxon.find( #{taxon_id} ).elastic_index!; Observation.elastic_index!( scope: Observation.of( #{taxon_id} ) )'"

cmd = "tar cvzf resurrect_#{taxon_id}.tgz resurrect_#{taxon_id}-*"
puts "Zipping it all up..."
puts "\t#{cmd}"
system cmd

cmd = "rm resurrect_#{taxon_id}-*"
puts "Cleaning up..."
puts "\t#{cmd}"
system cmd

puts
puts "Now run these commands (or something like them, depending on your setup):"
puts
puts <<-EOT
scp resurrect_#{taxon_id}.tgz inaturalist@taricha:deployment/production/current/
ssh -t inaturalist@taricha "cd deployment/production/current ; bash"
tar xzvf resurrect_#{taxon_id}.tgz
#{resurrection_cmds.uniq.join("\n")}
EOT
