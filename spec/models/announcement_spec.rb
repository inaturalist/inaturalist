# frozen_string_literal: true

require "spec_helper"

describe Announcement do
  it { is_expected.to have_and_belong_to_many :sites }

  it { is_expected.to validate_presence_of :placement }
  it { is_expected.to validate_presence_of :start }
  it { is_expected.to validate_presence_of :end }
  it { is_expected.to validate_presence_of :body }

  it "validates placement clients" do
    expect do
      Announcement.make!( placement: "users/dashboard#sidebar", clients: ["inat-ios"] )
    end.to raise_error( ActiveRecord::RecordInvalid, /Clients must be valid for specified placement/ )
    expect do
      Announcement.make!( placement: "users/dashboard#sidebar", clients: [] )
    end.not_to raise_error
    expect do
      Announcement.make!( placement: "mobile/home", clients: ["inat-ios"] )
    end.not_to raise_error
    expect do
      Announcement.make!( placement: "mobile/home", clients: ["nonsense"] )
    end.to raise_error( ActiveRecord::RecordInvalid, /Clients must be valid for specified placement/ )
    expect do
      Announcement.make!( placement: "mobile/home", clients: [] )
    end.not_to raise_error
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

    it "can exclude monthly supporters" do
      monthly_supporter = User.make!(
        donorbox_donor_id: 1,
        donorbox_plan_status: "active",
        donorbox_plan_type: "monthly"
      )
      non_monthly_supporter = User.make!
      a = Announcement.make!( prefers_exclude_monthly_supporters: true )
      expect( a.targeted_to_user?( monthly_supporter ) ).to be false
      expect( a.targeted_to_user?( non_monthly_supporter ) ).to be true
    end
  end
end
