# Migrate all photos with open licenses from the Static bucket to the Open bucket

max_photo_id = LocalPhoto.last.id
batch_size = 100000
index = 0

while index <= max_photo_id
  puts "Starting batch #{index}"
  LocalPhoto.delay(
      queue: "photos",
      unique_hash: { "LocalPhoto::migrate_to_odp_bucket": index }
    ).migrate_to_odp_bucket( index, index + batch_size - 1  )
  index += batch_size
end
