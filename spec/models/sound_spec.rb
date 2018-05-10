require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Sound, "license" do
  it "should use the user's default sound license" do
    u = User.make!
    u.preferred_sound_license = "CC-BY-NC"
    u.save
    s = Sound.make!(:user => u)
    expect(s.license).to eq Sound.license_number_for_code(u.preferred_sound_license)
  end
  
  it "should update default license when requested" do
    u = User.make!
    expect(u.preferred_sound_license).to be_blank
    Sound.make!(:user => u, :make_license_default => true, 
      :license => Sound.license_number_for_code(Observation::CC_BY_NC))
    u.reload
    expect(u.preferred_sound_license).to eq Observation::CC_BY_NC
  end
  
  it "should update all other sounds when requested" do
    u = User.make!
    s1 = Sound.make!(:user => u)
    s2 = Sound.make!(:user => u)
    expect(s1.license).to eq Sound::COPYRIGHT
    s2.make_licenses_same = true
    s2.license = Sound.license_number_for_code(Observation::CC_BY_NC)
    s2.save
    s1.reload
    expect(s1.license).to eq Sound.license_number_for_code(Observation::CC_BY_NC)
  end
  
  it "should nilify if not a license" do
    s = Sound.make!(:license => Sound.license_number_for_code(Observation::CC_BY))
    s.update_attributes(:license => "on")
    s.reload
    expect(s.license).to eq Sound::COPYRIGHT
  end
end

describe Sound, "destroy" do
  it "should create a deleted sound" do
    p = Sound.make!
    p.destroy
    deleted_sound = DeletedSound.where( sound_id: p.id ).first
    expect( deleted_sound ).not_to be_blank
    expect( deleted_sound.user_id ).to eq p.user_id
  end
end
