require "spec_helper.rb"

describe Announcement do
  it { is_expected.to have_and_belong_to_many :sites }

  it { is_expected.to validate_presence_of :placement }
  it { is_expected.to validate_presence_of :start }
  it { is_expected.to validate_presence_of :end }
  it { is_expected.to validate_presence_of :body }

  it "validates placement clients" do
    expect{
      Announcement.make!( placement: "users/dashboard#sidebar", clients: ["inat-ios"] )
    }.to raise_error(ActiveRecord::RecordInvalid, /Clients must be valid for specified placement/)
    expect{
      Announcement.make!( placement: "users/dashboard#sidebar", clients: [] )
    }.not_to raise_error
    expect{
      Announcement.make!( placement: "mobile/home", clients: ["inat-ios"] )
    }.not_to raise_error
    expect{
      Announcement.make!( placement: "mobile/home", clients: ["nonsense"] )
    }.to raise_error(ActiveRecord::RecordInvalid, /Clients must be valid for specified placement/)
    expect{
      Announcement.make!( placement: "mobile/home", clients: [] )
    }.not_to raise_error
  end

  describe "targeted_to_user" do
    it "targets admins with prefers_target_staff" do
      a = Announcement.make!( prefers_target_staff: true )
      expect( a.targeted_to_user?( make_admin ) ).to be true
      expect( a.targeted_to_user?( make_curator ) ).to be false
      expect( a.targeted_to_user?( User.make! ) ).to be false
    end

    it "targets unconfirmed users" do
      a = Announcement.make!( prefers_target_unconfirmed_users: true )
      expect( a.targeted_to_user?( User.make!( confirmed_at: Time.now ) ) ).to be false
      expect( a.targeted_to_user?( User.make!( confirmed_at: nil ) ) ).to be true
    end
  end

end
