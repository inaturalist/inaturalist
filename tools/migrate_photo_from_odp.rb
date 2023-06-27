# Migrate all photos with restricted license from the Open bucket to the Static bucket

max_photo_id = LocalPhoto.last.id
batch_size = 100000
index = 0

open_bucket_id = FilePrefix.where( prefix: "https://inaturalist-open-data.s3.amazonaws.com/photos" ).first.id

while index <= max_photo_id
  puts "Starting batch #{index}"
  LocalPhoto.where( license: Shared::LicenseModule::C, file_prefix_id: open_bucket_id ).
  where( "id between ? and ?", index, index + batch_size - 1 ).
  each do |photo|
    LocalPhoto.delay(
      queue: "photos",
      unique_hash: { "LocalPhoto::change_photo_bucket_if_needed": photo.id }
    ).change_photo_bucket_if_needed( photo )
  end
  index += batch_size
end
