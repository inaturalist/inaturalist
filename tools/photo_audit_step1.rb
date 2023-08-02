#
# Input:
#    list of photo ids, from a bucket (open or static)
#
# Output:
#    lists of photo ids from the input list that are
#      - in the photo table  
#      - not in the photo table
#

ts = Time.now.to_i.to_s

# Bucket configuration

bucket_prefix_id = FilePrefix.where( prefix: "https://static.inaturalist.org/photos" ).first.id

# List all "original" photo IDs

original_ids_csv_file_path = '/home/inaturalist/audit/original_ids.csv'
original_ids = []
CSV.foreach( original_ids_csv_file_path, headers: false ).each do |row|
  original_ids << row[0].to_i
end
original_ids = original_ids.uniq.sort
puts "original_ids = #{original_ids.length()}"

# Compare with "photos" table

batch_size = 100000
photo_ids = []
missing_photo_ids = []
current_batch_id = 0

original_ids.each_slice( batch_size ) do |batch_ids|
  found_ids = Photo.where( id: batch_ids, file_prefix_id: bucket_prefix_id ).pluck( :id )
  photo_ids += found_ids
  missing_photo_ids += batch_ids - found_ids
  current_batch_id += 1
  puts "Batch ##{current_batch_id}"
end

photo_ids = photo_ids.uniq
missing_photo_ids = missing_photo_ids.uniq

puts "original_ids = #{original_ids.length()}"
puts "photo_ids = #{photo_ids.length()}"
puts "missing_photo_ids = #{missing_photo_ids.length()}"

# Write results

photo_ids_csv_file_path = '/home/inaturalist/audit/photo_ids.'+ts+'.csv'
missing_photo_ids_csv_file_path = '/home/inaturalist/audit/missing_photo_ids.'+ts+'.csv'

CSV.open( photo_ids_csv_file_path, "w" ) do |w_csv|
  photo_ids.each do |ids|
    w_csv << [ids]
  end
end
CSV.open( missing_photo_ids_csv_file_path, "w" ) do |w_csv|
  missing_photo_ids.each do |ids|
    w_csv << [ids]
  end
end
