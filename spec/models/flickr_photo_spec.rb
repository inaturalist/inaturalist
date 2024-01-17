# frozen_string_literal: true

require "spec_helper"

describe FlickrPhoto do
  it { is_expected.to validate_presence_of :native_photo_id }

  describe FlickrPhoto, "creation" do
    before( :each ) do
      VCR.use_cassette( "flickr_photo_spec_setup" ) do
        setup_flickr_stuff
      end
    end

    it "should not save if there is no assoc'd iNat user and the pic isn't CC" do
      pending_flickr_setup do
        @non_cc_flickr_photo.user = nil
        @non_cc_flickr_photo.valid?
        expect( @non_cc_flickr_photo.errors[:license] ).to be_blank
      end
    end

    it "should make a valid FlickrPhoto from a flickr response" do
      expect( FlickrPhoto.new_from_flickr( @cc_flickr_photo_response, user: @user ) ).to be_valid
    end

    it "should not be valid if the associated user didn't take the photo" do
      expect( FlickrPhoto.new_from_api_response( @cc_flickr_photo_response, user: User.make! ) ).not_to be_valid
    end
  end

  describe FlickrPhoto, "updating" do
    elastic_models( Observation )

    before( :each ) do
      VCR.use_cassette( "flickr_photo_spec_setup" ) do
        setup_flickr_stuff
      end
    end

    it "should be valid if flickr identity blank but past observations exist" do
      pending_flickr_setup do
        o = Observation.make!( user: @user )
        o.photos << @cc_flickr_photo
        @user.flickr_identity.destroy
        @cc_flickr_photo.reload
        expect( @cc_flickr_photo ).to be_valid
      end
    end
  end

  describe FlickrPhoto, "to_observation" do
    before( :all ) do
      load_test_taxa
    end

    before( :each ) do
      VCR.use_cassette( "flickr_photo_spec_setup" ) do
        setup_flickr_stuff
      end
    end

    it "should create a valid observation" do
      pending_flickr_setup do
        expect( @cc_flickr_photo.to_observation ).to be_valid
      end
    end
  end

  describe FlickrPhoto, "to_taxon" do
    before( :each ) do
      VCR.use_cassette( "flickr_photo_spec_setup" ) do
        setup_flickr_stuff
      end
    end

    it "should use the title" do
      pending_flickr_setup do
        t = Taxon.make!
        @flickr_photo_hash["title"] = t.name
        r = Flickr::Response.build( @flickr_photo_hash, "photo" )
        fp = FlickrPhoto.new_from_api_response( r )
        expect( fp.to_taxon ).to eq t
      end
    end

    it "should parse a parenthesized taxon name out of the title" do
      pending_flickr_setup do
        tn = TaxonName.make!
        @flickr_photo_hash["title"] = "#{tn.name} (#{tn.taxon.name})"
        r = Flickr::Response.build( @flickr_photo_hash, "photo" )
        fp = FlickrPhoto.new_from_api_response( r )
        expect( fp.to_taxon ).to eq tn.taxon
      end
    end
  end
end

def setup_flickr_stuff
  @flickr_photo_hash = {
    "id" => "3670586632",
    "secret" => "0bd9d563e9",
    "server" => "3658",
    "farm" => 4,
    "dateuploaded" => "1246243085",
    "isfavorite" => 0,
    "license" => "2",
    "safety_level" => "0",
    "rotation" => 0,
    "originalsecret" => "57da5e30d2",
    "originalformat" => "jpg",
    "owner" => {
      "nsid" => "18024068@N00",
      "username" => "Ken-ichi",
      "realname" => "Ken-ichi Ueda",
      "location" => "Oakland, CA, United States",
      "iconserver" => "5335",
      "iconfarm" => 6,
      "path_alias" => "ken-ichi"
    },
    "title" => "Unknown Slug Eggs",
    "description" => "
      This was a hefty mass.  The blade of eel grass to which it was attached
      was about 1 cm wide, at least, so the mass must have been 6-7 cm wide.
      Definitely from a sea slug, but which one?  Looks a bit
      <i>Hermissenda</i>-ish, but that big?  Observed in &lt; 1 m of water in
      Tomales Bay, California, USA.",
    "visibility" => { "ispublic" => 1, "isfriend" => 0, "isfamily" => 0 },
    "dates" => { "posted" => "1246243085", "taken" => "2009-06-28 10:28:21", "takengranularity" => "0",
                 "lastupdate" => "1327389339" },
    "views" => "249",
    "editability" => { "cancomment" => 0, "canaddmeta" => 0 },
    "publiceditability" => { "cancomment" => 1, "canaddmeta" => 1 },
    "usage" => { "candownload" => 1, "canblog" => 0, "canprint" => 0, "canshare" => 1 },
    "comments" => "2",
    "notes" => [],
    "people" => { "haspeople" => 0 },
    "tags" => [
      { "id" => "1007768-3670586632-1337340", "author" => "18024068@N00", "authorname" => "Ken-ichi",
        "raw" => "California state parks", "_content" => "californiastateparks", "machine_tag" => 0 },
      { "id" => "1007768-3670586632-166302", "author" => "18024068@N00", "authorname" => "Ken-ichi",
        "raw" => "Tomales Bay", "_content" => "tomalesbay", "machine_tag" => 0 },
      { "id" => "1007768-3670586632-1045949", "author" => "18024068@N00", "authorname" => "Ken-ichi",
        "raw" => "Tomales Bay State Park", "_content" => "tomalesbaystatepark", "machine_tag" => 0 },
      { "id" => "1007768-3670586632-17947", "author" => "18024068@N00", "authorname" => "Ken-ichi", "raw" => "eggs",
        "_content" => "eggs", "machine_tag" => 0 },
      { "id" => "1007768-3670586632-288657", "author" => "18024068@N00", "authorname" => "Ken-ichi",
        "raw" => "state parks", "_content" => "stateparks", "machine_tag" => 0 }
    ],
    "location" => {
      "latitude" => 38.161262,
      "longitude" => -122.914727,
      "accuracy" => "16",
      "context" => "0",
      "locality" => { "_content" => "Lairds Landing", "place_id" => "S1rj1khTVrmEHNAz", "woeid" => "2434694" },
      "county" => { "_content" => "Marin", "place_id" => "V2NO5YxQUL8nrwLCyQ", "woeid" => "12587690" },
      "region" => { "_content" => "California", "place_id" => "NsbUWfBTUb4mbyVu", "woeid" => "2347563" },
      "country" => { "_content" => "United States", "place_id" => "nz.gsghTUb4c2WAecA", "woeid" => "23424977" },
      "place_id" => "S1rj1khTVrmEHNAz", "woeid" => "2434694"
    },
    "geoperms" => { "ispublic" => 1, "iscontact" => 0, "isfriend" => 0, "isfamily" => 0 },
    "urls" => [{ "type" => "photopage", "_content" => "http://www.flickr.com/photos/ken-ichi/3670586632/" }],
    "media" => "photo"
  }
  begin
    @user = User.make!
    @fi = FlickrIdentity.make!( user: @user, flickr_user_id: "18024068@N00" )

    json = JSON.parse( FLICKR_PHOTO_JSON )
    type, json = json.to_a.first
    @cc_flickr_photo_response = Flickr::Response.build( json, type )
    @cc_flickr_photo = FlickrPhoto.new_from_api_response( @cc_flickr_photo_response, user: @user )

    json = JSON.parse( NON_CC_FLICKR_PHOTO_JSON )
    type, json = json.to_a.first
    @non_cc_flickr_photo_response = Flickr::Response.build( json, type )
    @non_cc_flickr_photo = FlickrPhoto.new_from_api_response( @non_cc_flickr_photo_response, user: @user )

    @flickr_setup_exception = false
  rescue Flickr::FailedResponse => e
    @flickr_setup_exception = e
  end
end

def pending_flickr_setup( &block )
  if @flickr_setup_exception
    pending( "Flickr setup failed: #{@flickr_setup_exception}" )
    raise
  end
  block.call
end

FLICKR_PHOTO_JSON = <<~JSON
  { "photo": { "id": "2444432253", "secret": "82c3e12acf", "server": "2241", "farm": 3, "dateuploaded": "1209281517", "isfavorite": 0, "license": 2, "safety_level": 0, "rotation": 0, "originalsecret": "b31ef42992", "originalformat": "jpg",
      "owner": { "nsid": "18024068@N00", "username": "Ken-ichi", "realname": "Ken-ichi Ueda", "location": "Oakland, CA, United States", "iconserver": 22, "iconfarm": 1 },
      "title": { "_content": "Finally" },
      "description": { "_content": "Black Widows are't exactly uncommon, so why has it taken me this long to find one (or several).  I also found a bunch of males in addition to this female, and caught one.  Didn't get any good pics of it, but I may try later on if I can figure out how to get it to stay still in an open container without escaping or biting me." },
      "visibility": { "ispublic": 1, "isfriend": 0, "isfamily": 0 },
      "dates": { "posted": "1209281517", "taken": "2008-04-26 20:10:30", "takengranularity": 0, "lastupdate": "1327389307" },
      "permissions": { "permcomment": 3, "permaddmeta": 2 }, "views": "136",
      "editability": { "cancomment": 1, "canaddmeta": 1 },
      "publiceditability": { "cancomment": 1, "canaddmeta": 0 },
      "usage": { "candownload": 1, "canblog": 1, "canprint": 1, "canshare": 1 },
      "comments": { "_content": 3 },
      "notes": {
        "note": [ ] },
      "people": { "haspeople": 0 },
      "tags": {
        "tag": [
          { "id": "1007768-2444432253-128063", "author": "18024068@N00", "raw": "Arachnida", "_content": "arachnida", "machine_tag": 0 },
          { "id": "1007768-2444432253-34246", "author": "18024068@N00", "raw": "arachnids", "_content": "arachnids", "machine_tag": 0 },
          { "id": "1007768-2444432253-2129", "author": "18024068@N00", "raw": "Berkeley", "_content": "berkeley", "machine_tag": 0 },
          { "id": "1007768-2444432253-50", "author": "18024068@N00", "raw": "California", "_content": "california", "machine_tag": 0 },
          { "id": "1007768-2444432253-4074", "author": "18024068@N00", "raw": "United States", "_content": "unitedstates", "machine_tag": 0 },
          { "id": "1007768-2444432253-597692", "author": "18024068@N00", "raw": "Latrodectus", "_content": "latrodectus", "machine_tag": 0 },
          { "id": "1007768-2444432253-749775", "author": "18024068@N00", "raw": "Theridiidae", "_content": "theridiidae", "machine_tag": 0 }
        ] },
      "location": { "latitude": 37.87266, "longitude": -122.246247, "accuracy": 16, "context": 0,
        "neighbourhood": { "_content": "UC Berkeley", "place_id": "9qwABRNUV7LmHJPxvg", "woeid": "55858022" },
        "locality": { "_content": "Berkeley", "place_id": "4TuKIUlTUbxBjlKV", "woeid": "2362930" },
        "county": { "_content": "Alameda", "place_id": "1IvHpmpQUL8ZId.pmA", "woeid": "12587670" },
        "region": { "_content": "California", "place_id": "NsbUWfBTUb4mbyVu", "woeid": "2347563" },
        "country": { "_content": "United States", "place_id": "nz.gsghTUb4c2WAecA", "woeid": "23424977" }, "place_id": "9qwABRNUV7LmHJPxvg", "woeid": "55858022" },
      "geoperms": { "ispublic": 1, "iscontact": 0, "isfriend": 0, "isfamily": 0 },
      "urls": {
        "url": [
          { "type": "photopage", "_content": "http:\/\/www.flickr.com\/photos\/ken-ichi\/2444432253\/" }
        ] }, "media": "photo" }, "stat": "ok" }
JSON

NON_CC_FLICKR_PHOTO_JSON = <<~JSON
  { "photo": { "id": "2394365945", "secret": "61a6cfa033", "server": "3185", "farm": 4, "dateuploaded": "1207543164", "isfavorite": 0, "license": 2, "safety_level": 0, "rotation": 0, "originalsecret": "5b78e8fa13", "originalformat": "jpg",
      "owner": { "nsid": "18024068@N00", "username": "Ken-ichi", "realname": "Ken-ichi Ueda", "location": "Oakland, CA, United States", "iconserver": 22, "iconfarm": 1 },
      "title": { "_content": "O Fortuna" },
      "description": { "_content": "Sometimes I think I have something and it turns out bad, and other times I think there's nothing and it turns out good.  This is somewhere between.  If that center flower had just been in focus..." },
      "visibility": { "ispublic": 1, "isfriend": 0, "isfamily": 0 },
      "dates": { "posted": "1207543164", "taken": "2008-04-05 17:55:32", "takengranularity": 0, "lastupdate": "1327389306" },
      "permissions": { "permcomment": 3, "permaddmeta": 2 }, "views": 47,
      "editability": { "cancomment": 1, "canaddmeta": 1 },
      "publiceditability": { "cancomment": 1, "canaddmeta": 0 },
      "usage": { "candownload": 1, "canblog": 1, "canprint": 1, "canshare": 1 },
      "comments": { "_content": 1 },
      "notes": {
        "note": [ ] },
      "people": { "haspeople": 0 },
      "tags": {
        "tag": [
          { "id": "1007768-2394365945-140066", "author": "18024068@N00", "raw": "Arroyo Seco", "_content": "arroyoseco", "machine_tag": 0 },
          { "id": "1007768-2394365945-755198", "author": "18024068@N00", "raw": "Los Padres National Forest", "_content": "lospadresnationalforest", "machine_tag": 0 }
        ] },
      "urls": {
        "url": [
          { "type": "photopage", "_content": "http:\/\/www.flickr.com\/photos\/ken-ichi\/2394365945\/" }
        ] }, "media": "photo" }, "stat": "ok" }
JSON
