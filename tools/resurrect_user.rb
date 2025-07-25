# frozen_string_literal: true

user_id = ARGV[0]
table_names = []
resurrection_cmds = []
dbname = ActiveRecord::Base.connection.current_database

puts
puts <<-INFO
  This script assumes you're currently connected to a database that has the data
  you want to export, so if it bails b/c it can't find your user, that's
  probably why.
INFO
puts

system "rm resurrect_#{user_id}*"

puts "Exporting from users..."
fname = "resurrect_#{user_id}-users.csv"
column_names = User.column_names
cmd = "psql #{dbname} -c \"COPY (SELECT #{column_names.join( ', ' )} " \
  "FROM users WHERE id = #{user_id}) TO STDOUT WITH CSV\" > #{fname}"
puts "\t#{cmd}"
system cmd
resurrection_cmds << "psql #{dbname} -c \"\\COPY users " \
  "(#{column_names.join( ', ' )}) FROM '#{fname}' WITH CSV\""

has_many_reflections = User.reflections.select {| _k, v | v.macro == :has_many }
has_many_reflections.each do | k, reflection |
  # Avoid those pesky :through relats
  column_names = reflection.klass.column_names
  next unless reflection.klass.column_names.include?( reflection.foreign_key )
  next unless [:destroy, :delete_all].include?( reflection.options[:dependent] )
  next if %w(
    observations
    observation_field_values
    project_observations
    identifications
  ).include?( k.to_s )

  puts "Exporting #{k}..."
  fname = "resurrect_#{user_id}-#{reflection.table_name}.csv"
  unless table_names.include?( reflection.table_name )
    system "test #{fname} || rm #{fname}"
  end
  cmd = "psql #{dbname} -c \"COPY (SELECT #{column_names.join( ', ' )} " \
    "FROM #{reflection.table_name} " \
    "WHERE #{reflection.foreign_key} = #{user_id}"

  # if the reflection is polymorphic, we need to add an additional condition for the type column
  if %w(
    stored_preferences
  ).include?( k.to_s ) && reflection.options[:as]
    cmd += " AND #{reflection.table_name}.#{reflection.options[:as]}_type = 'User'"
  end

  cmd += ") TO STDOUT WITH CSV\" >> #{fname}"
  system cmd
  puts "\t#{cmd}"
  resurrection_cmds << "psql #{dbname} -c \"\\COPY #{reflection.table_name} " \
    "(#{column_names.join( ', ' )}) FROM '#{fname}' WITH CSV\""

  # Add commands to remove DeletedPhotos of restored Photos
  next unless reflection.table_name == "photos"

  photo_id_column_index = column_names.index( "id" )
  next unless photo_id_column_index && File.exist?( fname )

  photo_ids = []
  CSV.foreach( fname ) {| row | photo_ids << row[photo_id_column_index] }
  photo_ids.in_groups_of( 1000, false ) do | group_photo_ids |
    resurrection_cmds << "psql #{dbname} -c \"DELETE FROM deleted_photos " \
      "WHERE photo_id IN (#{group_photo_ids.join( ',' )})\""
  end
end

puts "Exporting from identifications..."
fname = "resurrect_#{user_id}-identifications.csv"
column_names = Identification.column_names
sql = <<-SQL
  SELECT #{column_names.map {| cn | "identifications.#{cn}" }.join( ', ' )}
  FROM
    identifications
      JOIN observations ON observations.id = identifications.observation_id
  WHERE
    identifications.user_id = #{user_id}
    AND observations.user_id != #{user_id}
SQL
cmd = "psql #{dbname} -c \"COPY (#{sql.gsub( '\n', ' ' )}) TO STDOUT WITH CSV\" > #{fname}"
puts "\t#{cmd}"
system cmd
resurrection_cmds << "psql #{dbname} -c \"\\COPY identifications " \
  "(#{column_names.join( ', ' )}) FROM '#{fname}' WITH CSV\""

puts "Exporting from identification preferences..."
fname = "resurrect_#{user_id}-identification-preferences.csv"
column_names = Preference.column_names
sql = <<-SQL
  SELECT #{column_names.map {| cn | "preferences.#{cn}" }.join( ', ' )}
  FROM
    preferences
      JOIN identifications ON (
        preferences.owner_id = identifications.id AND preferences.owner_type = 'Identification'
      ) JOIN observations ON observations.id = identifications.observation_id
  WHERE
    identifications.user_id = #{user_id}
    AND observations.user_id != #{user_id}
SQL
cmd = "psql #{dbname} -c \"COPY (#{sql.gsub( '\n', ' ' )}) TO STDOUT WITH CSV\" > #{fname}"
puts "\t#{cmd}"
system cmd
resurrection_cmds << "psql #{dbname} -c \"\\COPY preferences " \
  "(#{column_names.join( ', ' )}) FROM '#{fname}' WITH CSV\""

puts "Exporting from listed_taxa..."
fname = "resurrect_#{user_id}-listed_taxa.csv"
column_names = ListedTaxon.column_names
sql = <<-SQL
  SELECT #{column_names.map {| cn | "listed_taxa.#{cn}" }.join( ', ' )}
  FROM
    listed_taxa
      JOIN lists ON lists.id = listed_taxa.list_id
  WHERE
    lists.user_id = #{user_id}
SQL
cmd = "psql #{dbname} -c \"COPY (#{sql.gsub( '\n', ' ' )}) TO STDOUT WITH CSV\" > #{fname}"
puts "\t#{cmd}"
system cmd
resurrection_cmds << "psql #{dbname} -c \"\\COPY listed_taxa " \
  "(#{column_names.join( ', ' )}) FROM '#{fname}' WITH CSV\""

puts "Exporting from guide_taxa..."
fname = "resurrect_#{user_id}-guide_taxa.csv"
column_names = GuideTaxon.column_names
sql = <<-SQL
  SELECT #{column_names.map {| cn | "guide_taxa.#{cn}" }.join( ', ' )}
  FROM
    guide_taxa
      JOIN guides ON guides.id = guide_taxa.guide_id
  WHERE
    guides.user_id = #{user_id}
SQL
cmd = "psql #{dbname} -c \"COPY (#{sql.gsub( /\s+/, ' ' )}) TO STDOUT WITH CSV\" > #{fname}"
puts "\t#{cmd}"
system cmd
resurrection_cmds << "psql #{dbname} -c \"\\COPY guide_taxa " \
  "(#{column_names.join( ', ' )}) FROM '#{fname}' WITH CSV\""

%w(guide_photos guide_ranges guide_sections).each do | table_name |
  puts "Exporting from #{table_name}..."
  klass = Object.const_get( table_name.camelize.singularize )
  column_names = klass.column_names
  fname = "resurrect_#{user_id}-#{table_name}.csv"
  sql = <<-SQL
  SELECT
    #{column_names.map {| cn | "#{table_name}.#{cn}" }.join( ', ' )}
  FROM
    #{table_name}
      JOIN guide_taxa ON guide_taxa.id = #{table_name}.guide_taxon_id
      JOIN guides ON guides.id = guide_taxa.guide_id
  WHERE
    guides.user_id = #{user_id}
  SQL
  cmd = "psql #{dbname} -c \"COPY (#{sql.gsub( /\s+/, ' ' )}) TO STDOUT WITH CSV\" > #{fname}"
  puts "\t#{cmd}"
  system cmd
  resurrection_cmds << "psql #{dbname} -c \"\\COPY #{table_name} " \
    "(#{column_names.join( ', ' )}) FROM '#{fname}' WITH CSV\""
end

puts "Exporting from photo_metadata..."
fname = "resurrect_#{user_id}-photo_metadata.csv"
column_names = PhotoMetadata.column_names
sql = <<-SQL
  SELECT DISTINCT
    #{column_names.map {| cn | "photo_metadata.#{cn}" }.join( ', ' )}
  FROM photo_metadata
    JOIN photos ON photo_metadata.photo_id = photos.id
  WHERE photos.user_id = #{user_id}
SQL
cmd = "psql #{dbname} -c \"COPY (#{sql.gsub( /\s+/, ' ' )}) TO STDOUT WITH CSV\" > #{fname}"
puts "\t#{cmd}"
system cmd
resurrection_cmds << "psql #{dbname} -c \"\\COPY photo_metadata " \
  "(#{column_names.join( ', ' )}) FROM '#{fname}' WITH CSV\""

# TODO: restore subscriptions to user

cmd = "tar cvzf resurrect_#{user_id}.tgz resurrect_#{user_id}-*"
puts "Zipping it all up..."
puts "\t#{cmd}"
system cmd

cmd = "rm resurrect_#{user_id}-*"
puts "Cleaning up..."
puts "\t#{cmd}"
system cmd

puts
puts "Run these commands (or something like them, depending on your setup):"
puts
puts <<-CODE
  scp resurrect_#{user_id}.tgz inaturalist@taricha:deployment/production/current/
  ssh -t inaturalist@taricha "cd deployment/production/current ; bash"
  tar xzvf resurrect_#{user_id}.tgz
  #{resurrection_cmds.uniq.join( "\n  " )}
CODE
puts "\n\n"
puts "This script does not resurrect observations or associated data. Please use the following command:"
puts
puts "  bundle exec rails r tools/resurrect_observations.rb -u #{user_id} --skip Photo --skip Sound -r"
puts "\n\n"
puts "The DeletedUser entry should be removed after resurrecting a user account:"
puts
puts <<-CODE
  bundle exec rails r "DeletedUser.where( 'user_id = ?', #{user_id} ).destroy_all"
CODE
puts "\n\n\n"
