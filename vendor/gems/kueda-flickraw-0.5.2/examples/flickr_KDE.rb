#!/usr/bin/ruby
# Chooses a photo from the current interesting
# photo and set it as the background image on
# your first KDE desktop.

require 'flickraw'
require 'open-uri'
DESKTOP=1

list = flickr.interestingness.getList
photo = list[rand(100)]
sizes = flickr.photos.getSizes(:photo_id => photo.id)
original = sizes.find {|s| s.label == 'Original' }

url = original.source
file = File.basename url
full_path = File.join(Dir.pwd, file)

open url do |remote|
  open(file, 'wb') { |local| local << remote.read }
end

`dcop kdesktop KBackgroundIface setWallpaper #{DESKTOP} #{full_path} 7`
