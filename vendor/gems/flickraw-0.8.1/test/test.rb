# -*- coding: utf-8 -*-

require 'test/unit'
require 'lib/flickraw'

class Basic < Test::Unit::TestCase
  def test_request
    flickr_objects = %w{activity auth blogs collections commons contacts
       favorites galleries groups interestingness machinetags panda
       people photos photosets places prefs reflection tags
       test urls
    }
    assert_equal FlickRaw::Flickr.flickr_objects, flickr_objects
    flickr_objects.each {|o|
      assert_respond_to  flickr, o
      assert_kind_of FlickRaw::Request, eval("flickr." + o)
    }
  end
  
  def test_known
    known_methods = %w{
      flickr.activity.userComments
      flickr.activity.userPhotos
      flickr.auth.checkToken
      flickr.auth.getFrob
      flickr.auth.getFullToken
      flickr.auth.getToken
      flickr.blogs.getList
      flickr.blogs.getServices
      flickr.blogs.postPhoto
      flickr.collections.getInfo
      flickr.collections.getTree
      flickr.commons.getInstitutions
      flickr.contacts.getList
      flickr.contacts.getListRecentlyUploaded
      flickr.contacts.getPublicList
      flickr.favorites.add
      flickr.favorites.getList
      flickr.favorites.getPublicList
      flickr.favorites.remove
      flickr.galleries.addPhoto
      flickr.galleries.getList
      flickr.galleries.getListForPhoto
      flickr.groups.browse
      flickr.groups.getInfo
      flickr.groups.members.getList
      flickr.groups.pools.add
      flickr.groups.pools.getContext
      flickr.groups.pools.getGroups
      flickr.groups.pools.getPhotos
      flickr.groups.pools.remove
      flickr.groups.search
      flickr.interestingness.getList
      flickr.machinetags.getNamespaces
      flickr.machinetags.getPairs
      flickr.machinetags.getPredicates
      flickr.machinetags.getRecentValues
      flickr.machinetags.getValues
      flickr.panda.getList
      flickr.panda.getPhotos
      flickr.people.findByEmail
      flickr.people.findByUsername
      flickr.people.getInfo
      flickr.people.getPublicGroups
      flickr.people.getPublicPhotos
      flickr.people.getUploadStatus
      flickr.photos.addTags
      flickr.photos.comments.addComment
      flickr.photos.comments.deleteComment
      flickr.photos.comments.editComment
      flickr.photos.comments.getList
      flickr.photos.comments.getRecentForContacts
      flickr.photos.delete
      flickr.photos.geo.batchCorrectLocation
      flickr.photos.geo.correctLocation
      flickr.photos.geo.getLocation
      flickr.photos.geo.getPerms
      flickr.photos.geo.photosForLocation
      flickr.photos.geo.removeLocation
      flickr.photos.geo.setContext
      flickr.photos.geo.setLocation
      flickr.photos.geo.setPerms
      flickr.photos.getAllContexts
      flickr.photos.getContactsPhotos
      flickr.photos.getContactsPublicPhotos
      flickr.photos.getContext
      flickr.photos.getCounts
      flickr.photos.getExif
      flickr.photos.getFavorites
      flickr.photos.getInfo
      flickr.photos.getNotInSet
      flickr.photos.getPerms
      flickr.photos.getRecent
      flickr.photos.getSizes
      flickr.photos.getUntagged
      flickr.photos.getWithGeoData
      flickr.photos.getWithoutGeoData
      flickr.photos.licenses.getInfo
      flickr.photos.licenses.setLicense
      flickr.photos.notes.add
      flickr.photos.notes.delete
      flickr.photos.notes.edit
      flickr.photos.recentlyUpdated
      flickr.photos.removeTag
      flickr.photos.search
      flickr.photos.setContentType
      flickr.photos.setDates
      flickr.photos.setMeta
      flickr.photos.setPerms
      flickr.photos.setSafetyLevel
      flickr.photos.setTags
      flickr.photos.transform.rotate
      flickr.photos.upload.checkTickets
      flickr.photosets.addPhoto
      flickr.photosets.comments.addComment
      flickr.photosets.comments.deleteComment
      flickr.photosets.comments.editComment
      flickr.photosets.comments.getList
      flickr.photosets.create
      flickr.photosets.delete
      flickr.photosets.editMeta
      flickr.photosets.editPhotos
      flickr.photosets.getContext
      flickr.photosets.getInfo
      flickr.photosets.getList
      flickr.photosets.getPhotos
      flickr.photosets.orderSets
      flickr.photosets.removePhoto
      flickr.places.find
      flickr.places.findByLatLon
      flickr.places.getChildrenWithPhotosPublic
      flickr.places.getInfo
      flickr.places.getInfoByUrl
      flickr.places.getPlaceTypes
      flickr.places.getShapeHistory
      flickr.places.getTopPlacesList
      flickr.places.placesForBoundingBox
      flickr.places.placesForContacts
      flickr.places.placesForTags
      flickr.places.placesForUser
      flickr.places.resolvePlaceId
      flickr.places.resolvePlaceURL
      flickr.places.tagsForPlace
      flickr.prefs.getContentType
      flickr.prefs.getGeoPerms
      flickr.prefs.getHidden
      flickr.prefs.getPrivacy
      flickr.prefs.getSafetyLevel
      flickr.reflection.getMethodInfo
      flickr.reflection.getMethods
      flickr.tags.getClusterPhotos
      flickr.tags.getClusters
      flickr.tags.getHotList
      flickr.tags.getListPhoto
      flickr.tags.getListUser
      flickr.tags.getListUserPopular
      flickr.tags.getListUserRaw
      flickr.tags.getRelated
      flickr.test.echo
      flickr.test.login
      flickr.test.null
      flickr.urls.getGroup
      flickr.urls.getUserPhotos
      flickr.urls.getUserProfile
      flickr.urls.lookupGroup
      flickr.urls.lookupUser
    }
    found_methods = flickr.reflection.getMethods
    assert_instance_of FlickRaw::ResponseList, found_methods
    assert_equal known_methods, found_methods.to_a
  end
  
  def test_list
    list = flickr.photos.getRecent :per_page => '10'
    assert_instance_of FlickRaw::ResponseList, list
    assert_equal(list.size, 10)
  end
  
  def people(user)
    assert_equal "41650587@N02", user.id
    assert_equal "41650587@N02", user.nsid
    assert_equal "ruby_flickraw", user.username
  end
  
  def photo(info)
    assert_equal "3839885270", info.id
    assert_equal "41650587@N02", info.owner
    assert_equal "6fb8b54e06", info.secret
    assert_equal "2485", info.server
    assert_equal 3, info.farm
    assert_equal "cat", info.title
    assert_equal 1, info.ispublic
  end

  # favorites
  def test_favorites_getPublicList
    list = flickr.favorites.getPublicList :user_id => "41650587@N02"
    assert_equal 1, list.size
    assert_equal "3829093290", list[0].id
  end
  
  # groups
  def test_groups_getInfo
    info = flickr.groups.getInfo :group_id => "51035612836@N01"
    assert_equal "51035612836@N01", info.id
    assert_equal "Flickr API", info.name
  end
  
  def test_groups_search
    list = flickr.groups.search :text => "Flickr API"
    assert list.any? {|g| g.nsid == "51035612836@N01"}
  end
  
  # panda
  def test_panda_getList
    pandas = flickr.panda.getList
    assert_equal ["ling ling", "hsing hsing", "wang wang"], pandas.to_a
  end
  
  def test_panda_getList
    pandas = flickr.panda.getPhotos :panda_name => "wang wang"
    assert_equal "wang wang", pandas.panda
    assert_respond_to pandas[0], :title
  end
  
  # people
  def test_people_findByEmail
    user = flickr.people.findByEmail :find_email => "flickraw@yahoo.com"
    people user
  end
    
  def test_people_findByUsername
    user = flickr.people.findByUsername :username => "ruby_flickraw"
    people user
  end
  
  def test_people_getInfo
    user = flickr.people.getInfo :user_id => "41650587@N02"
    people user
    assert_equal "Flickraw", user.realname
    assert_equal "http://www.flickr.com/photos/41650587@N02/", user.photosurl
    assert_equal "http://www.flickr.com/people/41650587@N02/", user.profileurl
    assert_equal "http://m.flickr.com/photostream.gne?id=41630239", user.mobileurl
    assert_equal 0, user.ispro
  end
  
  def test_people_getPublicGroups
    groups = flickr.people.getPublicGroups :user_id => "41650587@N02"
    assert groups.to_a.empty?
  end
  
  def test_people_getPublicPhotos
    info = flickr.people.getPublicPhotos :user_id => "41650587@N02"
    assert_equal 1, info.size
    assert_equal "1", info.total
    assert_equal 1, info.pages
    assert_equal 1, info.page
    photo info[0]
  end
  
  # photos
  def test_photos_getInfo
    id = "3839885270"
    info = nil
    assert_nothing_raised(FlickRaw::FailedResponse) {
      info = flickr.photos.getInfo(:photo_id => id)
    }

     %w{id secret server farm license owner title description dates comments tags media}.each {|m|
      assert_respond_to info, m
      assert_not_nil info[m]
    }

    assert_equal id, info.id
    assert_equal "cat", info.title
    assert_equal "This is my cat", info.description
    assert_equal "ruby_flickraw", info.owner["username"]
    assert_equal "Flickraw", info.owner["realname"]
    assert_equal %w{cat pet}, info.tags.map {|t| t.to_s}.sort
  end
  
  def test_photos_getExif
    info = flickr.photos.getExif :photo_id => "3839885270"
    assert_equal "Canon DIGITAL IXUS 55", info.exif.find {|f| f.tag == "Model"}.raw
    assert_equal "1/60", info.exif.find {|f| f.tag == "ExposureTime"}.raw
    assert_equal "4.9", info.exif.find {|f| f.tag == "FNumber"}.raw
    assert_equal "1600", info.exif.find {|f| f.tag == "ImageWidth"}.raw
    assert_equal "1200", info.exif.find {|f| f.tag == "ImageHeight"}.raw
  end
  
  def test_photos_getSizes
    info = flickr.photos.getSizes :photo_id => "3839885270"
    assert_equal "http://www.flickr.com/photos/41650587@N02/3839885270/sizes/l/", info.find {|f| f.label == "Large"}.url
    assert_equal "http://farm3.static.flickr.com/2485/3839885270_6fb8b54e06_b.jpg", info.find {|f| f.label == "Large"}.source
  end
  
  def test_photos_search
    info = flickr.photos.search :user_id => "41650587@N02"
    photo info[0]
  end
  
  # photos.comments
  def test_photos_comments_getList
    comments = flickr.photos.comments.getList :photo_id => "3839885270"
    assert_equal 1, comments.size
    assert_equal "3839885270", comments.photo_id
    assert_equal "41630239-3839885270-72157621986549875", comments[0].id
    assert_equal "41650587@N02", comments[0].author
    assert_equal "ruby_flickraw", comments[0].authorname
    assert_equal "http://www.flickr.com/photos/41650587@N02/3839885270/#comment72157621986549875", comments[0].permalink
    assert_equal "This is a cute cat !", comments[0].to_s
  end
  
  # tags
  def test_tags_getListPhoto
    tags = flickr.tags.getListPhoto :photo_id => "3839885270"
    assert_equal 2, tags.tags.size
    assert_equal "3839885270", tags.id
    assert_equal %w{cat pet}, tags.tags.map {|t| t.to_s}.sort
  end
  
  def test_tags_getListUser
    tags =  flickr.tags.getListUser :user_id => "41650587@N02"
    assert_equal "41650587@N02", tags.id
    assert_equal %w{cat pet}, tags.tags.sort
  end
  
  # urls
  def test_urls_getGroup
    info = flickr.urls.getGroup :group_id => "51035612836@N01"
    assert_equal "51035612836@N01", info.nsid
    assert_equal "http://www.flickr.com/groups/api/", info.url
  end
  
  def test_urls_getUserPhotos
    info = flickr.urls.getUserPhotos :user_id => "41650587@N02"
    assert_equal "41650587@N02", info.nsid
    assert_equal "http://www.flickr.com/photos/41650587@N02/", info.url
  end
  
  def test_urls_getUserProfile
    info = flickr.urls.getUserProfile :user_id => "41650587@N02"
    assert_equal "41650587@N02", info.nsid
    assert_equal "http://www.flickr.com/people/41650587@N02/", info.url
  end
  
  def test_urls_lookupGroup
    info = flickr.urls.lookupGroup :url => "http://www.flickr.com/groups/api/"
    assert_equal "51035612836@N01", info.id
    assert_equal "Flickr API", info.groupname
  end
  
  def test_urls_lookupUser
    info = flickr.urls.lookupUser :url => "http://www.flickr.com/photos/41650587@N02/"
    assert_equal "41650587@N02", info.id
    assert_equal "ruby_flickraw", info.username
  end
  
  def test_urls
    id = "3839885270"
    info = flickr.photos.getInfo(:photo_id => id)

    assert_equal "http://farm3.static.flickr.com/2485/3839885270_6fb8b54e06.jpg", FlickRaw.url(info)
    assert_equal "http://farm3.static.flickr.com/2485/3839885270_6fb8b54e06_m.jpg", FlickRaw.url_m(info)
    assert_equal "http://farm3.static.flickr.com/2485/3839885270_6fb8b54e06_s.jpg", FlickRaw.url_s(info)
    assert_equal "http://farm3.static.flickr.com/2485/3839885270_6fb8b54e06_t.jpg", FlickRaw.url_t(info)
    assert_equal "http://farm3.static.flickr.com/2485/3839885270_6fb8b54e06_b.jpg", FlickRaw.url_b(info)

    assert_equal "http://www.flickr.com/people/41650587@N02/", FlickRaw.url_profile(info)
    assert_equal "http://www.flickr.com/photos/41650587@N02/", FlickRaw.url_photostream(info)
    assert_equal "http://www.flickr.com/photos/41650587@N02/3839885270", FlickRaw.url_photopage(info)
    assert_equal "http://www.flickr.com/photos/41650587@N02/sets/", FlickRaw.url_photosets(info)
    assert_equal "http://flic.kr/p/6Rjq7s", FlickRaw.url_short(info)
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
    assert_equal echo.utf8_text, utf8_text
  end
end
