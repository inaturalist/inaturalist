require 'test/unit'
require 'lib/flickraw'

# utf8 hack
def u(str)
  str.gsub(/\\+u([0-9a-fA-F]{4,4})/u){["#$1".hex ].pack('U*')}
end

class Basic < Test::Unit::TestCase
  def test_known
    known_methods = ["flickr.activity.userComments", "flickr.activity.userPhotos", "flickr.auth.checkToken", "flickr.auth.getFrob", "flickr.auth.getFullToken", "flickr.auth.getToken", "flickr.blogs.getList", "flickr.blogs.postPhoto", "flickr.contacts.getList", "flickr.contacts.getPublicList", "flickr.favorites.add", "flickr.favorites.getList", "flickr.favorites.getPublicList", "flickr.favorites.remove", "flickr.groups.browse", "flickr.groups.getInfo", "flickr.groups.pools.add", "flickr.groups.pools.getContext", "flickr.groups.pools.getGroups", "flickr.groups.pools.getPhotos", "flickr.groups.pools.remove", "flickr.groups.search", "flickr.interestingness.getList", "flickr.people.findByEmail", "flickr.people.findByUsername", "flickr.people.getInfo", "flickr.people.getPublicGroups", "flickr.people.getPublicPhotos", "flickr.people.getUploadStatus", "flickr.photos.addTags", "flickr.photos.comments.addComment", "flickr.photos.comments.deleteComment", "flickr.photos.comments.editComment", "flickr.photos.comments.getList", "flickr.photos.delete", "flickr.photos.geo.getLocation", "flickr.photos.geo.getPerms", "flickr.photos.geo.removeLocation", "flickr.photos.geo.setLocation", "flickr.photos.geo.setPerms", "flickr.photos.getAllContexts", "flickr.photos.getContactsPhotos", "flickr.photos.getContactsPublicPhotos", "flickr.photos.getContext", "flickr.photos.getCounts", "flickr.photos.getExif", "flickr.photos.getFavorites", "flickr.photos.getInfo", "flickr.photos.getNotInSet", "flickr.photos.getPerms", "flickr.photos.getRecent", "flickr.photos.getSizes", "flickr.photos.getUntagged", "flickr.photos.getWithGeoData", "flickr.photos.getWithoutGeoData", "flickr.photos.licenses.getInfo", "flickr.photos.licenses.setLicense", "flickr.photos.notes.add", "flickr.photos.notes.delete", "flickr.photos.notes.edit", "flickr.photos.recentlyUpdated", "flickr.photos.removeTag", "flickr.photos.search", "flickr.photos.setDates", "flickr.photos.setMeta", "flickr.photos.setPerms", "flickr.photos.setTags", "flickr.photos.transform.rotate", "flickr.photos.upload.checkTickets", "flickr.photosets.addPhoto", "flickr.photosets.comments.addComment", "flickr.photosets.comments.deleteComment", "flickr.photosets.comments.editComment", "flickr.photosets.comments.getList", "flickr.photosets.create", "flickr.photosets.delete", "flickr.photosets.editMeta", "flickr.photosets.editPhotos", "flickr.photosets.getContext", "flickr.photosets.getInfo", "flickr.photosets.getList", "flickr.photosets.getPhotos", "flickr.photosets.orderSets", "flickr.photosets.removePhoto", "flickr.reflection.getMethodInfo", "flickr.reflection.getMethods", "flickr.tags.getHotList", "flickr.tags.getListPhoto", "flickr.tags.getListUser", "flickr.tags.getListUserPopular", "flickr.tags.getListUserRaw", "flickr.tags.getRelated", "flickr.test.echo", "flickr.test.login", "flickr.test.null", "flickr.urls.getGroup", "flickr.urls.getUserPhotos", "flickr.urls.getUserProfile", "flickr.urls.lookupGroup", "flickr.urls.lookupUser"]
    found_methods = flickr.reflection.getMethods
    assert_instance_of Array, found_methods
    known_methods.each { |m| assert found_methods.include?(m), m}
  end

  def test_found
    found_methods = flickr.reflection.getMethods
    found_methods.each { |m|
      assert_nothing_raised {
        begin
          eval m
        rescue FlickRaw::FailedResponse
        end
      }
    }
  end

  def test_photos
    list = flickr.photos.getRecent :per_page => '10'
    assert_instance_of Array, list
    assert_equal(list.size, 10)

    id = secret = info = nil
    assert_nothing_raised(NoMethodError) {
      id = list[0].id
      secret = list[0].secret
    }
    assert_nothing_raised(FlickRaw::FailedResponse) {
      info = flickr.photos.getInfo :photo_id => id, :secret => secret
    }
    assert_respond_to info, :id
    assert_respond_to info, :secret
    assert_respond_to info, :title
    assert_respond_to info, :description
    assert_respond_to info, :owner
    assert_respond_to info, :dates
    assert_respond_to info, :comments
    assert_respond_to info, :tags
  end

  def test_url_escape
    result_set = nil
    assert_nothing_raised {
      result_set = flickr.photos.search :text => "family vacation"
    }
    assert_operator result_set.total.to_i, :>=, 0

    # Unicode tests
    echo = nil
    utf8_text = "Hélène François, €uro"
    assert_nothing_raised {
      echo = flickr.test.echo :utf8_text => utf8_text
    }
    assert_equal u(echo.utf8_text), utf8_text
  end
end
