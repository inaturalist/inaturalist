# Migrate all photos with open licenses from the Static bucket to the Open bucket

max_photo_id = LocalPhoto.last.id
batch_size = 100000
index = 0

static_bucket_id = FilePrefix.where( prefix: "https://static.inaturalist.org/photos" ).first.id

while index < max_photo_id
  puts "Starting batch #{index}"
  LocalPhoto.joins( "LEFT JOIN flags ON (photos.id = flags.flaggable_id)" ).
  where( "flags.id IS NULL" ).
  where( "photos.file_prefix_id=?", static_bucket_id ).
  where( "photos.license not in (?)", Shared::LicenseModule::LICENSE_NUMBERS - Shared::LicenseModule::ODP_LICENSES).
  where( "photos.id between ? and ?", index, index + batch_size - 1 ).
  each do |photo|
    LocalPhoto.delay(
      queue: "photos",
      unique_hash: { "LocalPhoto::change_photo_bucket_if_needed": photo.id }
    ).change_photo_bucket_if_needed( photo )
  end
  index += batch_size
end
