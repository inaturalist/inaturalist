require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Photo do
  before(:each) { enable_elastic_indexing( Observation ) }
  after(:each) { disable_elastic_indexing( Observation ) }
  describe "creation" do
    it "should not allow native_realname to be too big" do
      txt = <<-TXT
        Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod
        tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim
        veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea
        commodo consequat. Duis aute irure dolor in reprehenderit in voluptate
        velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint
        occaecat cupidatat non proident, sunt in culpa qui officia deserunt
        mollit anim id est laborum.
      TXT
      p = Photo.make!(:native_realname => txt, :native_username => txt)
      expect(p.native_realname.size).to be < 256
      expect(p.native_username.size).to be < 256
    end
  end

  describe "license" do
    it "should use the user's default photo license" do
      u = User.make!
      u.preferred_photo_license = "CC-BY-NC"
      u.save
      p = Photo.make!(:user => u)
      expect(p.license).to eq Photo.license_number_for_code(u.preferred_photo_license)
    end

    it "should update default license when requested" do
      u = User.make!
      expect(u.preferred_photo_license).to be_blank
      p = Photo.make!(:user => u, :make_license_default => true,
        :license => Photo.license_number_for_code(Observation::CC_BY_NC))
      u.reload
      expect(u.preferred_photo_license).to eq Observation::CC_BY_NC
    end

    it "should update all other photos when requested" do
      u = User.make!
      p1 = Photo.make!(:user => u)
      p2 = Photo.make!(:user => u)
      expect(p1.license).to eq Photo::COPYRIGHT
      p2.make_licenses_same = true
      p2.license = Photo.license_number_for_code(Observation::CC_BY_NC)
      p2.save
      p1.reload
      expect(p1.license).to eq Photo.license_number_for_code(Observation::CC_BY_NC)
    end

    it "should nilify if not a license" do
      p = Photo.make!(:license => Photo.license_number_for_code(Observation::CC_BY))
      p.update_attributes(:license => "on")
      p.reload
      expect(p.license).to eq Photo::COPYRIGHT
    end
  end

  describe "destroy" do
    it "should create a deleted photo" do
      p = Photo.make!
      p.destroy
      deleted_photos = DeletedPhoto.where(photo_id: p.id).first
      expect(deleted_photos).not_to be_blank
      expect(deleted_photos.user_id).to eq p.user_id
    end
  end

  describe "local_photo_from_remote_photo" do
    it "creates a LocalPhoto with the right attributes" do
      fp = FlickrPhoto.new(
        original_url: "https://static.inaturalist.org/sites/1-logo.png",
        native_photo_id: "a native_photo_id",
        native_page_url: "a native_page_url",
        native_username: "a native_username",
        native_realname: "a native_realname",
        license: 2,
        mobile: false,
        metadata: { meta: :data })
      lp = Photo.local_photo_from_remote_photo(fp)
      expect( lp.native_photo_id ).to eq fp.native_photo_id
      expect( lp.native_page_url ).to eq fp.native_page_url
      expect( lp.native_username ).to eq fp.native_username
      expect( lp.native_realname ).to eq fp.native_realname
      expect( lp.license ).to eq fp.license
      expect( lp.mobile ).to eq fp.mobile
      expect( lp.metadata ).to eq fp.metadata
      expect( lp.original_url ).to be nil
      expect( lp.subtype ).to eq "FlickrPhoto"
      expect( lp.native_original_image_url ).to eq fp.original_url
    end
  end

  describe "turn_remote_photo_into_local_photo" do
    it "creates and saves local photos" do
      fp = FlickrPhoto.new(
        original_url: "https://static.inaturalist.org/sites/1-logo.png")
      expect(fp.type).to eq "FlickrPhoto"
      Photo.turn_remote_photo_into_local_photo(fp)
      expect(fp.type).to eq "LocalPhoto"
      expect(fp.subtype).to eq "FlickrPhoto"
      expect(fp.native_original_image_url).to eq fp.original_url
    end

    it "fails if the original and large URLs are inaccessible" do
      fp = FlickrPhoto.new(
        original_url: "https://static.inaturalist.org/whatever.png",
        large_url: "https://static.inaturalist.org/whatever.png")
      Photo.turn_remote_photo_into_local_photo(fp)
      expect(fp.type).to eq "FlickrPhoto"
    end

    it "uses the large URL when the original is not available" do
      fp = FlickrPhoto.new(
        original_url: "https://static.inaturalist.org/whatever.png",
        large_url: "https://static.inaturalist.org/sites/1-logo.png")
      Photo.turn_remote_photo_into_local_photo(fp)
      expect(fp.type).to eq "LocalPhoto"
      expect(fp.native_original_image_url).to eq fp.large_url
    end
  end

  describe "attribution_name" do
    it "should not be blank even if the user's name is a blank string" do
      u = User.make!( name: "" )
      p = make_local_photo( user: u )
      expect( u.name ).to eq ""
      expect( p.attribution_name ).to eq u.login
    end
  end

end
