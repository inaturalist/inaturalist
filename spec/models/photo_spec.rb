require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Photo, "license" do
  it "should use the user's default photo license" do
    u = User.make!
    u.preferred_photo_license = "CC-BY-NC"
    u.save
    p = Photo.make!(:user => u)
    p.license.should == Photo.license_number_for_code(u.preferred_photo_license)
  end
  
  it "should update default license when requested" do
    u = User.make!
    u.preferred_photo_license.should be_blank
    p = Photo.make!(:user => u, :make_license_default => true, 
      :license => Photo.license_number_for_code(Observation::CC_BY_NC))
    u.reload
    u.preferred_photo_license.should == Observation::CC_BY_NC
  end
  
  it "should update all other photos when requested" do
    u = User.make!
    p1 = Photo.make!(:user => u)
    p2 = Photo.make!(:user => u)
    p1.license.should == Photo::COPYRIGHT
    p2.make_licenses_same = true
    p2.license = Photo.license_number_for_code(Observation::CC_BY_NC)
    p2.save
    p1.reload
    p1.license.should == Photo.license_number_for_code(Observation::CC_BY_NC)
  end
  
  it "should nilify if not a license" do
    p = Photo.make!(:license => Photo.license_number_for_code(Observation::CC_BY))
    p.update_attributes(:license => "on")
    p.reload
    p.license.should == Photo::COPYRIGHT
  end
end