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

  it "validates target group partitions" do
    expect do
      Announcement.make!( target_group_type: "user_id_parity", target_group_partition: "something new" )
    end.to raise_error( ActiveRecord::RecordInvalid, /Target group partition must be valid for specified target group/ )
    expect do
      Announcement.make!( target_group_type: "user_id_parity", target_group_partition: "even" )
    end.not_to raise_error
    expect do
      Announcement.make!( target_group_type: "user_id_parity", target_group_partition: "odd" )
    end.not_to raise_error
    expect do
      Announcement.make!( target_group_type: "user_id_parity", target_group_partition: nil )
    end.to raise_error( ActiveRecord::RecordInvalid, /Target group partition must be valid for specified target group/ )
    expect do
      Announcement.make!( target_group_type: nil, target_group_partition: nil )
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

    it "can target users by ID parity" do
      a = Announcement.make!( target_group_type: "user_id_parity", target_group_partition: "even" )
      expect( a.targeted_to_user?( User.make!( id: 100 ) ) ).to be true
      expect( a.targeted_to_user?( User.make!( id: 101 ) ) ).to be false
      expect( a.targeted_to_user?( User.make!( id: 200 ) ) ).to be true
      expect( a.targeted_to_user?( User.make!( id: 201 ) ) ).to be false

      a = Announcement.make!( target_group_type: "user_id_parity", target_group_partition: "odd" )
      expect( a.targeted_to_user?( User.make!( id: 300 ) ) ).to be false
      expect( a.targeted_to_user?( User.make!( id: 301 ) ) ).to be true
      expect( a.targeted_to_user?( User.make!( id: 400 ) ) ).to be false
      expect( a.targeted_to_user?( User.make!( id: 401 ) ) ).to be true
    end

    it "can target users by ID sum parity" do
      a = Announcement.make!( target_group_type: "user_id_digit_sum_parity", target_group_partition: "even" )
      expect( a.targeted_to_user?( User.make!( id: 100 ) ) ).to be false
      expect( a.targeted_to_user?( User.make!( id: 101 ) ) ).to be true
      expect( a.targeted_to_user?( User.make!( id: 200 ) ) ).to be true
      expect( a.targeted_to_user?( User.make!( id: 201 ) ) ).to be false

      a = Announcement.make!( target_group_type: "user_id_digit_sum_parity", target_group_partition: "odd" )
      expect( a.targeted_to_user?( User.make!( id: 300 ) ) ).to be true
      expect( a.targeted_to_user?( User.make!( id: 301 ) ) ).to be false
      expect( a.targeted_to_user?( User.make!( id: 400 ) ) ).to be false
      expect( a.targeted_to_user?( User.make!( id: 401 ) ) ).to be true
    end

    it "can target users by created second parity" do
      a = Announcement.make!( target_group_type: "created_second_parity", target_group_partition: "even" )
      expect( a.targeted_to_user?( User.make!( created_at: "2024-01-01 00:00:00" ) ) ).to be true
      expect( a.targeted_to_user?( User.make!( created_at: "2024-01-01 00:00:00" ) ) ).to be true
      expect( a.targeted_to_user?( User.make!( created_at: "2024-01-01 00:00:01" ) ) ).to be false
      expect( a.targeted_to_user?( User.make!( created_at: "2024-01-01 00:00:01" ) ) ).to be false
      expect( a.targeted_to_user?( User.make!( created_at: "2024-01-01 00:00:02" ) ) ).to be true
      expect( a.targeted_to_user?( User.make!( created_at: "2024-01-01 00:00:03" ) ) ).to be false
    end

    it "can target donors by donation date" do
      a = Announcement.make!( include_donor_start_date: Date.today )
      expect( a.targeted_to_user?( UserDonation.make!.user ) ).to be true
      expect( a.targeted_to_user?( UserDonation.make!( donated_at: 2.days.ago ).user ) ).to be false
      expect( a.targeted_to_user?( User.make! ) ).to be false
      expect( a.targeted_to_user?( nil ) ).to be false

      a = Announcement.make!( include_donor_end_date: 1.day.ago )
      expect( a.targeted_to_user?( UserDonation.make!.user ) ).to be false
      expect( a.targeted_to_user?( UserDonation.make!( donated_at: 2.days.ago ).user ) ).to be true
      expect( a.targeted_to_user?( User.make! ) ).to be false
      expect( a.targeted_to_user?( nil ) ).to be false

      a = Announcement.make!( include_donor_start_date: 10.days.ago, include_donor_end_date: 1.day.ago )
      expect( a.targeted_to_user?( UserDonation.make!.user ) ).to be false
      expect( a.targeted_to_user?( UserDonation.make!( donated_at: 2.days.ago ).user ) ).to be true
      expect( a.targeted_to_user?( UserDonation.make!( donated_at: 20.days.ago ).user ) ).to be false
      expect( a.targeted_to_user?( User.make! ) ).to be false
      expect( a.targeted_to_user?( nil ) ).to be false
    end

    it "can exclude donors by donation date" do
      a = Announcement.make!( exclude_donor_start_date: Date.today )
      expect( a.targeted_to_user?( UserDonation.make!.user ) ).to be false
      expect( a.targeted_to_user?( UserDonation.make!( donated_at: 2.days.ago ).user ) ).to be true
      expect( a.targeted_to_user?( User.make! ) ).to be true
      expect( a.targeted_to_user?( nil ) ).to be true

      a = Announcement.make!( exclude_donor_end_date: 1.day.ago )
      expect( a.targeted_to_user?( UserDonation.make!.user ) ).to be true
      expect( a.targeted_to_user?( UserDonation.make!( donated_at: 2.days.ago ).user ) ).to be false
      expect( a.targeted_to_user?( User.make! ) ).to be true
      expect( a.targeted_to_user?( nil ) ).to be true

      a = Announcement.make!( exclude_donor_start_date: 10.days.ago, exclude_donor_end_date: 1.day.ago )
      expect( a.targeted_to_user?( UserDonation.make!.user ) ).to be true
      expect( a.targeted_to_user?( UserDonation.make!( donated_at: 2.days.ago ).user ) ).to be false
      expect( a.targeted_to_user?( UserDonation.make!( donated_at: 20.days.ago ).user ) ).to be true
      expect( a.targeted_to_user?( User.make! ) ).to be true
      expect( a.targeted_to_user?( nil ) ).to be true
    end
  end
end
