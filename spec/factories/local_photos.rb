FactoryBot.define do
  factory :local_photo do
    user
    square_url { 'http://staticdev.inaturalist.org/photos/1234/square.jpg' }
    thumb_url { 'http://staticdev.inaturalist.org/photos/1234/thumb.jpg' }
    small_url { 'http://staticdev.inaturalist.org/photos/1234/small.jpg' }
    medium_url { 'http://staticdev.inaturalist.org/photos/1234/medium.jpg' }
    large_url { 'http://staticdev.inaturalist.org/photos/1234/large.jpg' }
    original_url { 'http://staticdev.inaturalist.org/photos/1234/original.jpg' }
    native_page_url { 'http://localhost:3000/photos/1234' }
    file_content_type { 'image/jpeg' }
    file_file_name { 'foo.jpg' }
    file_updated_at { Time.now }
  end
end
