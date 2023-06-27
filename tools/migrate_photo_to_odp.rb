# Migrate all photos with open licenses (not 0,8,10) from the Static bucket to the Open bucket

max_photo_id = LocalPhoto.last.id
batch_size = 100000
index = 0

while index < max_photo_id
	LocalPhoto.joins("LEFT JOIN flags ON (photos.id = flags.flaggable_id)").
  where("flags.id IS NULL").
  where("photos.file_prefix_id=2")
  where("photos.license not in (0,8,10)").
  where("photos.id between ? and ?", index, index + batch_size -1).
	find_each do |photo|
	  LocalPhoto.delay(
	      queue: "photos",
	      unique_hash: { "LocalPhoto::migrate_open_photo_to_odp_bucket": photo.id }
	    ).change_photo_bucket_if_needed( photo )
	end
	index = index + batch_size
end
