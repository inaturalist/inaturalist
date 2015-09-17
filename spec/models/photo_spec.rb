require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Photo do
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
end
