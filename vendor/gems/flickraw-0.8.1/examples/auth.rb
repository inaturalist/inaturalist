require 'flickraw'

# This is how to authenticate on flickr website.
# You need an API key for that, see http://www.flickr.com/services/api/keys/
API_KEY=''
SHARED_SECRET=''

FlickRaw.api_key=API_KEY
FlickRaw.shared_secret=SHARED_SECRET

frob = flickr.auth.getFrob
auth_url = FlickRaw.auth_url :frob => frob, :perms => 'read'

puts "Open this url in your process to complete the authication process : #{auth_url}"
puts "Press Enter when you are finished."
STDIN.getc

begin
  flickr.auth.getToken :frob => frob
  login = flickr.test.login
  puts "You are now authenticated as #{login.username}"
rescue FlickRaw::FailedResponse => e
  puts "Authentication failed : #{e.msg}"
end

