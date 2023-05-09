FactoryBot.define do
  factory :local_photo do
    user
    native_page_url { 'http://localhost:3000/photos/1234' }
    file_content_type { 'image/jpeg' }
    file_file_name { 'foo.jpg' }
    file_updated_at { Time.now }
    file_extension {
      FileExtension.find_or_create_by( extension: "jpg" )
    }
    file_prefix {
      FilePrefix.find_or_create_by( prefix: "http://staticdev.inaturalist.org/photos/" )
    }
  end
end
