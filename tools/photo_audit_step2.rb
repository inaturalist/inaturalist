#
# Input:
#    list of photo ids, from a bucket (open or static),
#    that don't exist in the photos table 
#
# Output:
#    lists of photo ids from the input list that are 
#      - in the deleted table
#      - not in the deleted table (error)
#      - flagged as removed from S3 (error)
#      - orphan and older than 2 months (error)
#      - orphan and more recent than 2 months
#      - not orphan and older than 7 months (error)
#      - not orphan and more recent than 7 months
#

ts = Time.now.to_i.to_s

missing_photo_ids_csv_file_path = '/home/inaturalist/audit/missing_photo_ids.XXXX.csv'

# List "missing" photo IDs

missing_ids = []
CSV.foreach(missing_photo_ids_csv_file_path, headers: false).each do |row|
  id = row[0].to_i
  if id <= 305004718
    missing_ids << id
  end
end
missing_ids = missing_ids.uniq.sort
puts "missing_ids = #{missing_ids.length()}"

# Compare missing photos with "deleted_photos" table

batch_size = 1000
two_month_ago = Time.now - 2.month
seven_month_ago = Time.now - 7.month
deleted_photo_ids = []
removed_from_s3_photo_ids = []
orphan_old_photos_ids = []
orphan_recent_photos_ids = []
not_orphan_old_photos_ids = []
not_orphan_recent_photos_ids = []
current_batch_id = 0

missing_ids.each_slice(batch_size) do |batch_ids|
  deleted_photos = DeletedPhoto.where(photo_id: batch_ids)
  deleted_photos.each do |photo|
  	deleted_photo_ids << photo.photo_id
  	if photo.removed_from_s3
  	  removed_from_s3_photo_ids << photo.photo_id
  	else
      if photo.orphan
        if photo.created_at < two_month_ago
          orphan_old_photos_ids << photo.photo_id
        else
          orphan_recent_photos_ids << photo.photo_id
        end	  	
  	  else
        if photo.created_at < seven_month_ago
          not_orphan_old_photos_ids << photo.photo_id
        else
          not_orphan_recent_photos_ids << photo.photo_id
        end	  	
  	  end
  	end
  end
  current_batch_id += 1
  puts "Batch ##{current_batch_id}"
end

not_deleted_photo_ids = (missing_ids - deleted_photo_ids).uniq
deleted_photo_ids = deleted_photo_ids.uniq
removed_from_s3_photo_ids = removed_from_s3_photo_ids.uniq
orphan_old_photos_ids = orphan_old_photos_ids.uniq
orphan_recent_photos_ids = orphan_recent_photos_ids.uniq
not_orphan_old_photos_ids = not_orphan_old_photos_ids.uniq
not_orphan_recent_photos_ids = not_orphan_recent_photos_ids.uniq

puts "missing_ids = #{missing_ids.length()}"
puts "not_deleted_photo_ids = #{not_deleted_photo_ids.length()}"
puts "deleted_photo_ids = #{deleted_photo_ids.length()}"
puts "removed_from_s3_photo_ids = #{removed_from_s3_photo_ids.length()}"
puts "orphan_old_photos_ids = #{orphan_old_photos_ids.length()}"
puts "orphan_recent_photos_ids = #{orphan_recent_photos_ids.length()}"
puts "not_orphan_old_photos_ids = #{not_orphan_old_photos_ids.length()}"
puts "not_orphan_recent_photos_ids = #{not_orphan_recent_photos_ids.length()}"

# Write results

not_deleted_photo_ids_csv_file_path = '/home/inaturalist/audit/not_deleted_photo_ids.'+ts+'.csv'
deleted_photo_ids_csv_file_path = '/home/inaturalist/audit/deleted_photo_ids.'+ts+'.csv'
removed_from_s3_photo_ids_csv_file_path = '/home/inaturalist/audit/removed_from_s3_photo_ids.'+ts+'.csv'
orphan_old_photos_ids_csv_file_path = '/home/inaturalist/audit/orphan_old_photos_ids.'+ts+'.csv'
orphan_recent_photos_ids_csv_file_path = '/home/inaturalist/audit/orphan_recent_photos_ids.'+ts+'.csv'
not_orphan_old_photos_ids_csv_file_path = '/home/inaturalist/audit/not_orphan_old_photos_ids.'+ts+'.csv'
not_orphan_recent_photos_ids_csv_file_path = '/home/inaturalist/audit/not_orphan_recent_photos_ids.'+ts+'.csv'

CSV.open(not_deleted_photo_ids_csv_file_path, "w") do |w_csv|
  not_deleted_photo_ids.each do |ids|
    w_csv << [ids]
  end
end
CSV.open(deleted_photo_ids_csv_file_path, "w") do |w_csv|
  deleted_photo_ids.each do |ids|
    w_csv << [ids]
  end
end
CSV.open(removed_from_s3_photo_ids_csv_file_path, "w") do |w_csv|
  removed_from_s3_photo_ids.each do |ids|
    w_csv << [ids]
  end
end
CSV.open(orphan_old_photos_ids_csv_file_path, "w") do |w_csv|
  orphan_old_photos_ids.each do |ids|
    w_csv << [ids]
  end
end
CSV.open(orphan_recent_photos_ids_csv_file_path, "w") do |w_csv|
  orphan_recent_photos_ids.each do |ids|
    w_csv << [ids]
  end
end
CSV.open(not_orphan_old_photos_ids_csv_file_path, "w") do |w_csv|
  not_orphan_old_photos_ids.each do |ids|
    w_csv << [ids]
  end
end
CSV.open(not_orphan_recent_photos_ids_csv_file_path, "w") do |w_csv|
  not_orphan_recent_photos_ids.each do |ids|
    w_csv << [ids]
  end
end
