#
# Input:
#    list of photo ids, from a bucket (open or static),
#    that exist in the photos table 
#
# Output:
#    list of photo ids from the input list that are 
#    not associated to observation nor taxon (error)
#

ts = Time.now.to_i.to_s

photo_ids_csv_file_path = '/home/inaturalist/audit/photo_ids.XXXX.csv'

# List "photos" photo IDs

photo_ids = []
CSV.foreach( photo_ids_csv_file_path, headers: false ).each do |row|
  photo_ids << row[0].to_i
end
photo_ids = photo_ids.uniq.sort
puts "photo_ids = #{photo_ids.length()}"

# Compare photos with "observation_photos" and "taxon_photos" table

batch_size = 100000
not_observation_or_taxon_photo_ids = []
current_batch_id = 0

photo_ids.each_slice( batch_size ) do |batch_ids|
  
  observation_photos_ids = ObservationPhoto.where( photo_id: batch_ids ).pluck( :photo_id )
  taxon_photos_ids = TaxonPhoto.where( photo_id: batch_ids ).pluck( :photo_id )

  not_observation_or_taxon_photo_ids += ( batch_ids - observation_photos_ids - taxon_photos_ids )

  current_batch_id += 1
  puts "Batch ##{current_batch_id}"
end

puts "photo_ids = #{photo_ids.length()}"
puts "not_observation_or_taxon_photo_ids = #{not_observation_or_taxon_photo_ids.length()}"

# Write results

not_observation_or_taxon_photo_ids_csv_file_path = '/home/inaturalist/audit/not_observation_or_taxon_photo_ids.'+ts+'.csv'

CSV.open( not_observation_or_taxon_photo_ids_csv_file_path, "w" ) do |w_csv|
  not_observation_or_taxon_photo_ids.each do |ids|
    w_csv << [ids]
  end
end
