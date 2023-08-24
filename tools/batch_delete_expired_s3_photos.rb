# Delete expired S3 photos by batch

min_photo_id = DeletedPhoto.still_in_s3.first.id
max_photo_id = DeletedPhoto.still_in_s3.last.id
batch_size = 100000
index = min_photo_id

while index <= max_photo_id
  puts "Starting batch #{index}"
  DeletedPhoto.delay(
      queue: "photos",
      unique_hash: { "DeletedPhoto::remove_from_s3_batch": index }
    ).remove_from_s3_batch( index, index + batch_size )
  index += batch_size
end

