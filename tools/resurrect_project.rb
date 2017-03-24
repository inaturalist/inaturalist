record_id = ARGV[0]
table_names = []
resurrection_cmds = []

system "rm resurrect_#{record_id}*"

puts "Exporting from projects..."
fname = "resurrect_#{record_id}-projects.csv"
dbconfig = Rails.configuration.database_configuration[Rails.env]
psql_cmd = "psql"
psql_cmd += " -h #{dbconfig['host']}" if dbconfig['host']
psql_cmd += " -U #{dbconfig['username']}" if dbconfig['username']
psql_cmd += " #{dbconfig['database']}"
cmd = "#{psql_cmd} -c \"COPY (SELECT * FROM projects WHERE id = #{record_id}) TO STDOUT WITH CSV\" > #{fname}"
puts "\t#{cmd}"
system cmd
resurrection_cmds << "psql inaturalist_production -c \"\\copy projects FROM '#{fname}' WITH CSV\""

update_statements = []

has_many_reflections = Project.reflections.select{|k,v| v.macro == :has_many || v.macro == :has_one}
has_many_reflections.each do |k, reflection|
  # Avoid those pesky :through relats
  next unless reflection.klass.column_names.include?(reflection.foreign_key)
  next unless [:delete_all, :destroy].include?(reflection.options[:dependent])
  next if k.to_s == "photos"
  puts "Exporting #{k}..."
  fname = "resurrect_#{record_id}-#{reflection.table_name}.csv"
  unless table_names.include?(reflection.table_name)
    system "test #{fname} || rm #{fname}"
  end
  cmd = "#{psql_cmd} -c \"COPY (SELECT * FROM #{reflection.table_name} WHERE #{reflection.foreign_key} = #{record_id}) TO STDOUT WITH CSV\" >> #{fname}"
  system cmd
  puts "\t#{cmd}"
  resurrection_cmds << "psql inaturalist_production -c \"\\copy #{reflection.table_name} FROM '#{fname}' WITH CSV\""
end

puts "Exporting from listed_taxa..."
fname = "resurrect_#{record_id}-listed_taxa.csv"
sql = <<-SQL
SELECT listed_taxa.* 
FROM 
  listed_taxa 
    JOIN lists ON lists.id = listed_taxa.list_id
WHERE
  lists.project_id = #{record_id}
SQL
cmd = "#{psql_cmd} -c \"COPY (#{sql.gsub("\n", ' ')}) TO STDOUT WITH CSV\" > #{fname}"
puts "\t#{cmd}"
system cmd
resurrection_cmds << "psql inaturalist_production -c \"\\copy listed_taxa FROM '#{fname}' WITH CSV\""

puts "Exporting from assessment_sections..."
fname = "resurrect_#{record_id}-assessment_sections.csv"
sql = <<-SQL
SELECT assessment_sections.* 
FROM 
  assessment_sections 
    JOIN assessments ON assessments.id = assessment_sections.assessment_id
WHERE
  assessments.project_id = #{record_id}
SQL
cmd = "#{psql_cmd} -c \"COPY (#{sql.gsub("\n", ' ')}) TO STDOUT WITH CSV\" > #{fname}"
puts "\t#{cmd}"
system cmd
resurrection_cmds << "psql inaturalist_production -c \"\\copy assessment_sections FROM '#{fname}' WITH CSV\""

[Post, AssessmentSection].each do |klass|
  puts "Exporting #{klass.name.underscore.humanize} on posts..."
  fname = "resurrect_#{record_id}-#{klass.name.underscore}-comments.csv"
  sql = if klass == Project
    <<-SQL
      SELECT comments.* 
      FROM 
        comments 
          JOIN posts ON posts.id = comments.parent_id
      WHERE
        comments.parent_type = '#{klass.name}'
        AND posts.parent_type = 'Project'
        AND posts.parent_id = #{record_id}
      SQL
  else
    <<-SQL
      SELECT comments.* 
      FROM 
        comments 
          JOIN assessment_sections ON assessment_sections.id = comments.parent_id
          JOIN assessments ON assessments.id = assessment_sections.assessment_id
      WHERE
        comments.parent_type = 'AssessmentSection'
        AND assessments.project_id = #{record_id}
      SQL
  end
  cmd = "#{psql_cmd} -c \"COPY (#{sql.gsub("\n", ' ')}) TO STDOUT WITH CSV\" > #{fname}"
  puts "\t#{cmd}"
  system cmd
  resurrection_cmds << "psql inaturalist_production -c \"\\copy comments FROM '#{fname}' WITH CSV\""
end

resurrection_cmds << "bundle exec rails r 'p = Project.find(#{record_id}); p.elastic_index!; Observation.elastic_index!( scope: p.observations )'"

cmd = "tar cvzf resurrect_#{record_id}.tgz resurrect_#{record_id}-*"
puts "Zipping it all up..."
puts "\t#{cmd}"
system cmd

cmd = "rm resurrect_#{record_id}-*"
puts "Cleaning up..."
puts "\t#{cmd}"
# system cmd

puts
puts "Now run these commands (or something like them, depending on your setup):"
puts
puts <<-EOT
scp resurrect_#{record_id}.tgz inaturalist@taricha:deployment/production/current/
ssh -t inaturalist@taricha "cd deployment/production/current ; bash"
tar xzvf resurrect_#{record_id}.tgz
#{resurrection_cmds.uniq.join("\n")}
EOT
