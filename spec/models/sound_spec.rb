require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Sound, "license" do
  it "should use the user's default sound license" do
    u = User.make!
    u.preferred_sound_license = "CC-BY-NC"
    u.save
    s = Sound.make!(:user => u)
    s.license.should == Sound.license_number_for_code(u.preferred_sound_license)
  end
  
  it "should update default license when requested" do
    u = User.make!
    u.preferred_sound_license.should be_blank
    Sound.make!(:user => u, :make_license_default => true, 
      :license => Sound.license_number_for_code(Observation::CC_BY_NC))
    u.reload
    u.preferred_sound_license.should == Observation::CC_BY_NC
  end
  
  it "should update all other sounds when requested" do
    u = User.make!
    s1 = Sound.make!(:user => u)
    s2 = Sound.make!(:user => u)
    s1.license.should == Sound::COPYRIGHT
    s2.make_licenses_same = true
    s2.license = Sound.license_number_for_code(Observation::CC_BY_NC)
    s2.save
    s1.reload
    s1.license.should == Sound.license_number_for_code(Observation::CC_BY_NC)
  end
  
  it "should nilify if not a license" do
    s = Sound.make!(:license => Sound.license_number_for_code(Observation::CC_BY))
    s.update_attributes(:license => "on")
    s.reload
    s.license.should == Sound::COPYRIGHT
  end
end