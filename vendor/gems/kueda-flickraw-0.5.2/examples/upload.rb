require 'flickraw'

# This is how to upload photos on flickr.
# You need to be authentified to do that.
API_KEY=''
SHARED_SECRET=''
PHOTO_PATH='photo.jpg'

FlickRaw.api_key=API_KEY
FlickRaw.shared_secret=SHARED_SECRET

frob = flickr.auth.getFrob
auth_url = FlickRaw.auth_url :frob => frob, :perms => 'write'

puts "Open this url in your process to complete the authication process : #{auth_url}"
puts "Press Enter when you are finished."
STDIN.getc

flickr.auth.getToken :frob => frob
login = flickr.test.login

flickr.upload_photo PHOTO_PATH, :title => 'Title', :description => 'This is the description'
