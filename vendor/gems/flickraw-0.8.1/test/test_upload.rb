# -*- coding: utf-8 -*-

require 'test/unit'
require 'lib/flickraw'

# FlickRaw.shared_secret = # Shared secret
# flickr.auth.checkToken :auth_token => # Auth token

class Upload < Test::Unit::TestCase
  def test_upload

    path = File.dirname(__FILE__) + '/image testée.jpg'
    u = info = nil
    title = "Titre de l'image testée"
    description = "Ceci est la description de l'image testée"
    assert_nothing_raised {
      u = flickr.upload_photo path,
        :title => title,
        :description => description
    }

    assert_nothing_raised {
      info = flickr.photos.getInfo :photo_id => u.to_s
    }

    assert_equal title, info.title
    assert_equal description, info.description

    assert_nothing_raised {flickr.photos.delete :photo_id => u.to_s}
  end
end
