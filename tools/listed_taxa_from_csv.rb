# This is a simple script that takes a CSV file in the form
# 
#   list_id,taxon_id,place_id,taxon_range_id
# 
# and inserts the rows into the listed_taxa table.  It will attempt to remove
# rows that match existing list_id,taxon_id pairs, and perform post-hoc
# integrity checks to make sure the foreign keys are still valid.  It will ask
# you whether you want to proceed with deleting rows with invalid foreign
# keys.

require 'rubygems'
require 'fileutils'
require 'open3'

DEBUG = false

unless input_path = ARGV[0]
  puts "You must specify an input file"
  exit(0)
end

input_path = File.expand_path(input_path)

unless File.exists?(input_path)
  puts "#{input_path} doesn't exist"
  exit(0)
end

def run_sql(sql, inpath = nil)
  sql_start = Time.now
  sql = sql.gsub(/\s+/, ' ').strip
  cmd = "nice psql inaturalist_production -c \"#{sql}\""
  cmd += " < #{inpath}" if inpath
  puts "EXECUTING #{cmd}..."
  # system cmd unless DEBUG
  unless DEBUG
    stdin, stdout, stderr = Open3.popen3(cmd).map do |io|
      s = io.read.strip rescue nil
      io.close
      s
    end
    [stdout, stderr].each do |io|
      puts io unless io.to_s.strip.size == 0
      if io =~ /error/i
        puts "Bailing!"
        exit(0)
      end
    end
  end
  puts "Finished in #{Time.now - sql_start}s"
  puts
end

start = Time.now
foreign_keys = {
  "taxa" => "taxon_id",
  "places" => "place_id",
  "taxon_ranges" => "taxon_range_id",
  "lists" => "list_id"
}

puts "FILTER OUT EXISTING"
existing_fname = "existing-#{start.to_i}.csv"
cmd = "psql inaturalist_production -c \"COPY listed_taxa (list_id, taxon_id) TO STDOUT WITH CSV\" > #{existing_fname}"
puts cmd
system cmd

puts "Building lookup..."
existing_lookup = {}
CSV.foreach(existing_fname, :headers => %w(list_id taxon_id)) do |row|
  existing_lookup[row['taxon_id']] ||= []
  existing_lookup[row['taxon_id']] << row['list_id']
end

puts "Filtering input..."
new_fname = "new-#{start.to_i}.csv"
leftovers_fname = "leftovers-#{start.to_i}.csv"
new_csv = CSV.open(new_fname, 'w')
leftovers_csv = CSV.open(leftovers_fname, 'w')
count = 0
CSV.foreach(input_path) do |row|
  next if row.nil? || row.size == 0
  list_id, taxon_id = row
  if existing_lookup[taxon_id] && existing_lookup[taxon_id].detect{|id| id == list_id}
    leftovers_csv << row
  else
    new_csv << row
    count += 1
  end
end
new_csv.close
leftovers_csv.close
existing_lookup = nil
GC.start
new_path = File.expand_path(new_fname)
puts "Copied #{count} lines into #{new_path}, leftovers in #{leftovers_fname}"

puts
run_sql "COPY listed_taxa (list_id, taxon_id, place_id, taxon_range_id, establishment_means) FROM STDIN WITH CSV", new_path

puts
puts "UPDATING EXISTING..."
existing_count = %x{wc -l #{leftovers_fname}}.split.first.to_i
i = 0
CSV.foreach(leftovers_fname, :headers => %w(list_id taxon_id place_id taxon_range_id establishment_means)) do |row|
  puts "#{i} of #{existing_count}"
  run_sql <<-SQL
    UPDATE listed_taxa SET taxon_range_id = #{row['taxon_range_id']}
    WHERE 
      taxon_range_id IS NULL AND
      list_id = #{row['list_id']} AND 
      taxon_id = #{row['taxon_id']}
  SQL
  if row['establishment_means']
    run_sql <<-SQL
      UPDATE listed_taxa SET establishment_means = '#{row['establishment_means']}'
      WHERE 
        establishment_means IS NULL AND
        list_id = #{row['list_id']} AND 
        taxon_id = #{row['taxon_id']}
    SQL
  end
  i += 1
end

foreign_keys.each do |table, key|
  puts
  puts "INTEGRETY CHECK FOR #{key}"
  invalid_ids_sql = <<-SQL
    SELECT lt.id 
    FROM 
      listed_taxa lt 
        LEFT OUTER JOIN #{table} f ON f.id = lt.#{key}
    WHERE 
      lt.#{key} IS NOT NULL AND 
      f.id IS NULL
  SQL
  run_sql invalid_ids_sql.sub('lt.id', 'count(*)')
  
  print "Delete listed taxa with invalid #{key}? (y/N)"
  response = STDIN.gets
  if response.strip.downcase == 'y'
    run_sql "DELETE FROM listed_taxa WHERE id IN (#{invalid_ids_sql})"
  end
end

puts
puts "DUPLCATE CHECK"
run_sql "SELECT list_id, taxon_id, min(id), max(id), count(*) FROM listed_taxa GROUP BY list_id, taxon_id HAVING count(*) > 1"
print "Delete most recent duplicates? (y/N)"
response = STDIN.gets
if response.strip.downcase == 'y'
  run_sql "DELETE FROM listed_taxa WHERE id IN (SELECT max(id) FROM listed_taxa GROUP BY list_id, taxon_id HAVING count(*) > 1)"
end

puts "VACUUMING..."
run_sql "VACUUM ANALYZE listed_taxa"

puts "CLEANING UP..."
FileUtils.rm(new_path)
FileUtils.rm(existing_fname)

puts "FINISHED ALL IN #{Time.now - start}s"
