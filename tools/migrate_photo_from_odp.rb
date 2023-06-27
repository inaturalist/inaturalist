# Migrate all photos with restricted license (0) from the Open bucket to the Static bucket

max_photo_id = LocalPhoto.last.id
batch_size = 100000
index = 0

while index < max_photo_id
	LocalPhoto.where( license: 0, file_prefix_id: 1 ).
	where("id between ? and ?", index, index + batch_size -1).
	find_each do |photo|
	  LocalPhoto.delay(
	      queue: "photos",
	      unique_hash: { "LocalPhoto::migrate_restricted_photo_from_odp_bucket": photo.id }
	    ).change_photo_bucket_if_needed( photo )
	end
	index = index + batch_size
end
