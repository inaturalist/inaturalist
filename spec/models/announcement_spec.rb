# frozen_string_literal: true

require "spec_helper"

describe Announcement do
  it { is_expected.to have_and_belong_to_many :sites }

  it { is_expected.to validate_presence_of :placement }
  it { is_expected.to validate_presence_of :start }
  it { is_expected.to validate_presence_of :end }
  it { is_expected.to validate_presence_of :body }
  it { is_expected.to validate_numericality_of( :min_identifications ).allow_nil.is_greater_than_or_equal_to 0 }
  it { is_expected.to validate_numericality_of( :max_identifications ).allow_nil.is_greater_than_or_equal_to 0 }
  it { is_expected.to validate_numericality_of( :min_observations ).allow_nil.is_greater_than_or_equal_to 0 }
  it { is_expected.to validate_numericality_of( :max_observations ).allow_nil.is_greater_than_or_equal_to 0 }

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

  describe "saving" do
    it "removes blank values from ip_countries" do
      a = create( :announcement, ip_countries: ["US", ""] )
      expect( a.ip_countries ).to eq ["US"]
    end
  end

  describe "targeted_to_user" do
    it "targets admins with prefers_target_staff" do
      a = Announcement.make!( prefers_target_staff: true )
      expect( a.targeted_to_user?( make_admin ) ).to be true
      expect( a.targeted_to_user?( make_curator ) ).to be false
      expect( a.targeted_to_user?( User.make! ) ).to be false
    end

    it "targets creator" do
      a = create :announcement, target_creator: true
      expect( a.targeted_to_user?( make_admin ) ).to be false
      expect( a.targeted_to_user?( make_curator ) ).to be false
      expect( a.targeted_to_user?( User.make! ) ).to be false
      expect( a.targeted_to_user?( a.user ) ).to be true
    end

    it "targets unconfirmed users" do
      a = create( :announcement, target_logged_in: Announcement::YES, prefers_target_unconfirmed_users: true )
      expect( a.targeted_to_user?( User.make!( confirmed_at: Time.now ) ) ).to be false
      expect( a.targeted_to_user?( User.make!( confirmed_at: nil ) ) ).to be true
    end

    it "targets unconfirmed users and last observation date" do
      annc = create :announcement,
        target_logged_in: Announcement::YES,
        prefers_target_unconfirmed_users: true,
        last_observation_start_date: 2.days.ago
      confirmed_user = create :user
      expect( confirmed_user ).to be_confirmed
      unconfirmed_user = create :user, :as_unconfirmed
      unconfirmed_user_no_obs = create :user, :as_unconfirmed
      expect( unconfirmed_user ).not_to be_confirmed
      create :observation, created_at: 1.day.ago, user: confirmed_user
      create :observation, created_at: 1.day.ago, user: unconfirmed_user
      expect( annc.targeted_to_user?( unconfirmed_user ) ).to be true
      expect( annc.targeted_to_user?( confirmed_user ) ).to be false
      expect( annc.targeted_to_user?( unconfirmed_user_no_obs ) ).to be false
    end

    it "can exclude monthly donorbox supporters" do
      monthly_supporter = User.make!(
        donorbox_donor_id: 1,
        donorbox_plan_status: "active",
        donorbox_plan_type: "monthly"
      )
      non_monthly_supporter = User.make!
      a = create( :announcement, target_logged_in: Announcement::YES, prefers_exclude_monthly_supporters: true )
      expect( a.targeted_to_user?( monthly_supporter ) ).to be false
      expect( a.targeted_to_user?( non_monthly_supporter ) ).to be true
    end

    it "can exclude monthly fundraiseup supporters" do
      monthly_supporter = User.make!(
        virtuous_donor_contact_id: 1,
        fundraiseup_plan_status: "active",
        fundraiseup_plan_frequency: "monthly"
      )
      non_monthly_supporter = User.make!
      a = create( :announcement, target_logged_in: Announcement::YES, prefers_exclude_monthly_supporters: true )
      expect( a.targeted_to_user?( monthly_supporter ) ).to be false
      expect( a.targeted_to_user?( non_monthly_supporter ) ).to be true
    end

    it "can target users by ID parity" do
      a = create(
        :announcement,
        target_logged_in: Announcement::YES,
        target_group_type: "user_id_parity",
        target_group_partition: "even"
      )
      expect( a.targeted_to_user?( User.make!( id: 100 ) ) ).to be true
      expect( a.targeted_to_user?( User.make!( id: 101 ) ) ).to be false
      expect( a.targeted_to_user?( User.make!( id: 200 ) ) ).to be true
      expect( a.targeted_to_user?( User.make!( id: 201 ) ) ).to be false

      a = create(
        :announcement,
        target_logged_in: Announcement::YES,
        target_group_type: "user_id_parity",
        target_group_partition: "odd"
      )
      expect( a.targeted_to_user?( User.make!( id: 300 ) ) ).to be false
      expect( a.targeted_to_user?( User.make!( id: 301 ) ) ).to be true
      expect( a.targeted_to_user?( User.make!( id: 400 ) ) ).to be false
      expect( a.targeted_to_user?( User.make!( id: 401 ) ) ).to be true
    end

    it "can target users by ID sum parity" do
      a = create(
        :announcement,
        target_logged_in: Announcement::YES,
        target_group_type: "user_id_digit_sum_parity",
        target_group_partition: "even"
      )
      expect( a.targeted_to_user?( User.make!( id: 100 ) ) ).to be false
      expect( a.targeted_to_user?( User.make!( id: 101 ) ) ).to be true
      expect( a.targeted_to_user?( User.make!( id: 200 ) ) ).to be true
      expect( a.targeted_to_user?( User.make!( id: 201 ) ) ).to be false

      a = create(
        :announcement,
        target_logged_in: Announcement::YES,
        target_group_type: "user_id_digit_sum_parity",
        target_group_partition: "odd"
      )
      expect( a.targeted_to_user?( User.make!( id: 300 ) ) ).to be true
      expect( a.targeted_to_user?( User.make!( id: 301 ) ) ).to be false
      expect( a.targeted_to_user?( User.make!( id: 400 ) ) ).to be false
      expect( a.targeted_to_user?( User.make!( id: 401 ) ) ).to be true
    end

    it "can target users by created second parity" do
      a = create(
        :announcement,
        target_logged_in: Announcement::YES,
        target_group_type: "created_second_parity",
        target_group_partition: "even"
      )
      expect( a.targeted_to_user?( User.make!( created_at: "2024-01-01 00:00:00" ) ) ).to be true
      expect( a.targeted_to_user?( User.make!( created_at: "2024-01-01 00:00:00" ) ) ).to be true
      expect( a.targeted_to_user?( User.make!( created_at: "2024-01-01 00:00:01" ) ) ).to be false
      expect( a.targeted_to_user?( User.make!( created_at: "2024-01-01 00:00:01" ) ) ).to be false
      expect( a.targeted_to_user?( User.make!( created_at: "2024-01-01 00:00:02" ) ) ).to be true
      expect( a.targeted_to_user?( User.make!( created_at: "2024-01-01 00:00:03" ) ) ).to be false
    end

    it "can target donors by donation date" do
      a = create(
        :announcement,
        target_logged_in: Announcement::YES,
        include_donor_start_date: Date.today
      )
      expect( a.targeted_to_user?( UserDonation.make!.user ) ).to be true
      expect( a.targeted_to_user?( UserDonation.make!( donated_at: 2.days.ago ).user ) ).to be false
      expect( a.targeted_to_user?( User.make! ) ).to be false
      expect( a.targeted_to_user?( nil ) ).to be false

      a = create(
        :announcement,
        target_logged_in: Announcement::YES,
        include_donor_end_date: 1.day.ago
      )
      expect( a.targeted_to_user?( UserDonation.make!.user ) ).to be false
      expect( a.targeted_to_user?( UserDonation.make!( donated_at: 2.days.ago ).user ) ).to be true
      expect( a.targeted_to_user?( User.make! ) ).to be false
      expect( a.targeted_to_user?( nil ) ).to be false

      a = create(
        :announcement,
        target_logged_in: Announcement::YES,
        include_donor_start_date: 10.days.ago, include_donor_end_date: 1.day.ago )
      expect( a.targeted_to_user?( UserDonation.make!.user ) ).to be false
      expect( a.targeted_to_user?( UserDonation.make!( donated_at: 2.days.ago ).user ) ).to be true
      expect( a.targeted_to_user?( UserDonation.make!( donated_at: 20.days.ago ).user ) ).to be false
      expect( a.targeted_to_user?( User.make! ) ).to be false
      expect( a.targeted_to_user?( nil ) ).to be false
    end

    it "can exclude donors by donation date" do
      a = create(
        :announcement,
        target_logged_in: Announcement::YES,
        exclude_donor_start_date: Date.today
      )
      expect( a.targeted_to_user?( UserDonation.make!.user ) ).to be false
      expect( a.targeted_to_user?( UserDonation.make!( donated_at: 2.days.ago ).user ) ).to be true
      expect( a.targeted_to_user?( User.make! ) ).to be true
      expect( a.targeted_to_user?( nil ) ).to be false

      a = create(
        :announcement,
        target_logged_in: Announcement::YES,
        exclude_donor_end_date: 1.day.ago
      )
      expect( a.targeted_to_user?( UserDonation.make!.user ) ).to be true
      expect( a.targeted_to_user?( UserDonation.make!( donated_at: 2.days.ago ).user ) ).to be false
      expect( a.targeted_to_user?( User.make! ) ).to be true
      expect( a.targeted_to_user?( nil ) ).to be false

      a = create(
        :announcement,
        target_logged_in: Announcement::YES,
        exclude_donor_start_date: 10.days.ago,
        exclude_donor_end_date: 1.day.ago
      )
      expect( a.targeted_to_user?( UserDonation.make!.user ) ).to be true
      expect( a.targeted_to_user?( UserDonation.make!( donated_at: 2.days.ago ).user ) ).to be false
      expect( a.targeted_to_user?( UserDonation.make!( donated_at: 20.days.ago ).user ) ).to be true
      expect( a.targeted_to_user?( User.make! ) ).to be true
      expect( a.targeted_to_user?( nil ) ).to be false
    end

    describe "target_logged_in" do
      it "defaults to targeting all" do
        annc = create :announcement
        expect( annc.target_logged_in ).to eq Announcement::ANY
        expect( annc.targeted_to_user?( nil ) ).to be true
        expect( annc.targeted_to_user?( create( :user ) ) ).to be true
      end

      it "can target logged in" do
        annc = create :announcement, target_logged_in: Announcement::YES
        expect( annc.targeted_to_user?( nil ) ).to be false
        expect( annc.targeted_to_user?( create( :user ) ) ).to be true
      end

      it "can target logged out" do
        annc = create :announcement, target_logged_in: Announcement::NO
        expect( annc.targeted_to_user?( nil ) ).to be true
        expect( annc.targeted_to_user?( create( :user ) ) ).to be false
      end
    end

    describe "target_curators" do
      it "defaults to targeting all" do
        annc = create :announcement
        expect( annc.target_curators ).to eq Announcement::ANY
        expect( annc.targeted_to_user?( nil ) ).to be true
        expect( annc.targeted_to_user?( create( :user ) ) ).to be true
      end

      it "can target curators" do
        annc = create :announcement, target_logged_in: Announcement::YES, target_curators: Announcement::YES
        expect( annc.targeted_to_user?( nil ) ).to be false
        expect( annc.targeted_to_user?( create( :user, :as_curator ) ) ).to be true
        expect( annc.targeted_to_user?( create( :user ) ) ).to be false
      end

      it "can target non-curators" do
        annc = create :announcement, target_logged_in: Announcement::YES, target_curators: Announcement::NO
        expect( annc.targeted_to_user?( nil ) ).to be false
        expect( annc.targeted_to_user?( create( :user, :as_curator ) ) ).to be false
        expect( annc.targeted_to_user?( create( :user ) ) ).to be true
      end
    end

    describe "target_project_admins" do
      it "defaults to targeting all" do
        annc = create :announcement
        expect( annc.target_project_admins ).to eq Announcement::ANY
        expect( annc.targeted_to_user?( nil ) ).to be true
        expect( annc.targeted_to_user?( create( :user ) ) ).to be true
      end

      it "can target project admins" do
        annc = create :announcement, target_logged_in: Announcement::YES, target_project_admins: Announcement::YES
        expect( annc.targeted_to_user?( nil ) ).to be false
        expect( annc.targeted_to_user?( create( :project ).user ) ).to be true
        expect( annc.targeted_to_user?( create( :user ) ) ).to be false
      end

      it "can target non-project admins" do
        annc = create :announcement, target_logged_in: Announcement::YES, target_project_admins: Announcement::NO
        expect( annc.targeted_to_user?( nil ) ).to be false
        expect( annc.targeted_to_user?( create( :project ).user ) ).to be false
        expect( annc.targeted_to_user?( create( :user ) ) ).to be true
      end
    end

    describe "min_identifications" do
      it "defaults to targeting all" do
        annc = create :announcement
        expect( annc.targeted_to_user?( nil ) ).to be true
        expect( annc.targeted_to_user?( create( :user ) ) ).to be true
        expect( annc.targeted_to_user?( create( :identification ).user ) ).to be true
      end

      it "includes users with more than value" do
        annc = create :announcement, target_logged_in: Announcement::YES, min_identifications: 1
        expect( annc.targeted_to_user?( nil ) ).to be false
        expect( annc.targeted_to_user?( create( :user ) ) ).to be false
        identifier = create :user, identifications_count: 2
        expect( identifier.identifications_count ).to eq 2
        expect( annc.targeted_to_user?( identifier ) ).to be true
      end
    end

    describe "max_identifications" do
      it "defaults to targeting all" do
        annc = create :announcement
        expect( annc.targeted_to_user?( nil ) ).to be true
        expect( annc.targeted_to_user?( create( :user ) ) ).to be true
        expect( annc.targeted_to_user?( create( :identification ).user ) ).to be true
      end

      it "includes users with less than value" do
        annc = create :announcement, target_logged_in: Announcement::YES, max_identifications: 2
        expect( annc.targeted_to_user?( nil ) ).to be false
        expect( annc.targeted_to_user?( create( :user ) ) ).to be true
        identifier = create :user, identifications_count: 1
        expect( identifier.identifications_count ).to eq 1
        expect( annc.targeted_to_user?( identifier ) ).to be true
      end

      it "exclude users with more than value" do
        annc = create :announcement, target_logged_in: Announcement::YES, max_identifications: 2
        expect( annc.targeted_to_user?( nil ) ).to be false
        expect( annc.targeted_to_user?( create( :user ) ) ).to be true
        identifier = create :user, identifications_count: 10
        expect( identifier.identifications_count ).to eq 10
        expect( annc.targeted_to_user?( identifier ) ).to be false
      end
    end

    describe "max_observations" do
      it "defaults to targeting all" do
        annc = create :announcement
        expect( annc.target_logged_in ).to eq Announcement::ANY
        expect( annc.targeted_to_user?( nil ) ).to be true
        expect( annc.targeted_to_user?( create( :user ) ) ).to be true
        expect( annc.targeted_to_user?( create( :observation ).user ) ).to be true
      end

      it "includes users with less than value" do
        annc = create :announcement, target_logged_in: Announcement::YES, max_observations: 2
        expect( annc.targeted_to_user?( nil ) ).to be false
        expect( annc.targeted_to_user?( create( :user ) ) ).to be true
        identifier = create :user, observations_count: 1
        expect( identifier.observations_count ).to eq 1
        expect( annc.targeted_to_user?( identifier ) ).to be true
      end

      it "exclude users with more than value" do
        annc = create :announcement, target_logged_in: Announcement::YES, max_observations: 2
        expect( annc.targeted_to_user?( nil ) ).to be false
        expect( annc.targeted_to_user?( create( :user ) ) ).to be true
        identifier = create :user, observations_count: 10
        expect( identifier.observations_count ).to eq 10
        expect( annc.targeted_to_user?( identifier ) ).to be false
      end
    end

    describe "user_created_start_date" do
      it "defaults to targeting all" do
        annc = create :announcement
        expect( annc.user_created_start_date ).to be_nil
        expect( annc.targeted_to_user?( nil ) ).to be true
        expect( annc.targeted_to_user?( create( :user ) ) ).to be true
      end

      it "includes users created after value" do
        annc = create :announcement, target_logged_in: Announcement::YES, user_created_start_date: 2.days.ago
        expect( annc.targeted_to_user?( create( :user, created_at: 1.day.ago ) ) ).to be true
      end

      it "excludes users created before value" do
        annc = create :announcement, target_logged_in: Announcement::YES, user_created_start_date: 2.days.ago
        expect( annc.targeted_to_user?( create( :user, created_at: 3.day.ago ) ) ).to be false
      end

      it "excludes signed out users" do
        annc = create :announcement, target_logged_in: Announcement::YES, user_created_start_date: 2.days.ago
        expect( annc.targeted_to_user?( nil ) ).to be false
      end
    end

    describe "user_created_end_date" do
      it "defaults to targeting all" do
        annc = create :announcement
        expect( annc.user_created_end_date ).to be_nil
        expect( annc.targeted_to_user?( nil ) ).to be true
        expect( annc.targeted_to_user?( create( :user ) ) ).to be true
      end

      it "includes users created before value" do
        annc = create :announcement, target_logged_in: Announcement::YES, user_created_end_date: 1.days.ago
        expect( annc.targeted_to_user?( create( :user, created_at: 2.day.ago ) ) ).to be true
      end

      it "excludes users created after value" do
        annc = create :announcement, target_logged_in: Announcement::YES, user_created_end_date: 2.days.ago
        expect( annc.targeted_to_user?( create( :user, created_at: 1.day.ago ) ) ).to be false
      end

      it "excludes signed out users" do
        annc = create :announcement, target_logged_in: Announcement::YES, user_created_end_date: 2.days.ago
        expect( annc.targeted_to_user?( nil ) ).to be false
      end
    end

    describe "last_observation_start_date" do
      it "includes users with last observation after value" do
        annc = create :announcement, target_logged_in: Announcement::YES, last_observation_start_date: 2.days.ago
        obs = create :observation, created_at: 1.day.ago
        expect( annc.targeted_to_user?( obs.user ) ).to be true
      end

      it "excludes users with last observation before value" do
        annc = create :announcement, target_logged_in: Announcement::YES, last_observation_start_date: 2.days.ago
        obs = create :observation, created_at: 3.day.ago
        expect( annc.targeted_to_user?( obs.user ) ).to be false
      end
    end

    describe "last_observation_end_date" do
      it "includes users with last observation before value" do
        annc = create :announcement, target_logged_in: Announcement::YES, last_observation_end_date: 1.days.ago
        obs = create :observation, created_at: 2.day.ago
        expect( annc.targeted_to_user?( obs.user ) ).to be true
      end

      it "excludes users with last observation after value" do
        annc = create :announcement, target_logged_in: Announcement::YES, last_observation_end_date: 2.days.ago
        obs = create :observation, created_at: 1.day.ago
        expect( annc.targeted_to_user?( obs.user ) ).to be false
      end
    end

    it "includes and excludes users by observation oauth application ids" do
      app_to_include = create :oauth_application, official: true
      app_to_exclude = create :oauth_application, official: true
      annc = create :announcement,
        target_logged_in: Announcement::YES,
        include_observation_oauth_application_ids: [app_to_include.id],
        exclude_observation_oauth_application_ids: [app_to_exclude.id]
      include_user = create( :observation, oauth_application: app_to_include ).user
      exclude_user = create( :observation, oauth_application: app_to_exclude ).user
      both_user = create :user
      create :observation, oauth_application: app_to_include, user: both_user
      create :observation, oauth_application: app_to_exclude, user: both_user
      expect( annc.targeted_to_user?( include_user ) ).to be true
      expect( annc.targeted_to_user?( exclude_user ) ).to be false
      expect( annc.targeted_to_user?( both_user ) ).to be false
    end

    it "includes and excludes users by virtuous tags" do
      tag_to_include = "Include"
      tag_to_exclude = "Exclude"
      annc = create :announcement,
        target_logged_in: Announcement::YES,
        include_virtuous_tags: [tag_to_include],
        exclude_virtuous_tags: [tag_to_exclude]
      include_user = UserVirtuousTag.make!( virtuous_tag: tag_to_include ).user
      exclude_user = UserVirtuousTag.make!( virtuous_tag: tag_to_exclude ).user
      both_user = User.make!
      UserVirtuousTag.make!( virtuous_tag: tag_to_include, user: both_user )
      UserVirtuousTag.make!( virtuous_tag: tag_to_exclude, user: both_user )
      expect( annc.targeted_to_user?( include_user ) ).to be true
      expect( annc.targeted_to_user?( exclude_user ) ).to be false
      expect( annc.targeted_to_user?( both_user ) ).to be false
      expect( annc.targeted_to_user?( User.make! ) ).to be false
    end
  end

  describe "dismissals" do
    it "creates AnnouncementDismissals for new dismissals" do
      user_ids_to_dismiss = ( 1..10 ).to_a
      announcement = Announcement.make!
      expect( AnnouncementDismissal.count ).to eq 0
      announcement.update( dismiss_user_ids: user_ids_to_dismiss )
      expect( AnnouncementDismissal.count ).to eq user_ids_to_dismiss.length
      user_ids_to_dismiss.each do | user_id |
        expect( AnnouncementDismissal.where( announcement: announcement, user_id: user_id ).count ).to eq 1
      end
    end

    it "deletes AnnouncementDismissals for removed dismissals" do
      user_ids_to_dismiss = ( 1..10 ).to_a
      announcement = Announcement.make!
      expect( AnnouncementDismissal.count ).to eq 0
      announcement.update( dismiss_user_ids: user_ids_to_dismiss )
      expect( AnnouncementDismissal.count ).to eq user_ids_to_dismiss.length
      announcement.update( dismiss_user_ids: [user_ids_to_dismiss.first] )
      expect( AnnouncementDismissal.count ).to eq 1
      expect( AnnouncementDismissal.where(
        announcement: announcement, user_id: user_ids_to_dismiss.first
      ).count ).to eq 1
    end
  end

  describe "active_in_placement" do
    describe "ip_country" do
      it "includes announcements with ip_countries matching IP country" do
        annc = create :announcement, ip_countries: ["US"]
        test_ip = "1.2.3.4"
        allow( INatAPIService ).to receive( :geoip_lookup ) do
          OpenStruct.new_recursive( results: { country: annc.ip_countries.first } )
        end
        expect( Announcement.active_in_placement( "users/dashboard#sidebar", { ip: test_ip } ) ).to include annc
      end

      it "excludes announcements with ip_countries not matching IP country" do
        annc = create :announcement, ip_countries: ["US"]
        test_ip = "1.2.3.4"
        allow( INatAPIService ).to receive( :geoip_lookup ) do
          OpenStruct.new_recursive( results: { country: "PL" } )
        end
        expect( Announcement.active_in_placement( "users/dashboard#sidebar", { ip: test_ip } ) ).not_to include annc
      end

      it "excludes announcements with ip_countries when IP has no country" do
        annc = create :announcement, ip_countries: ["US"]
        test_ip = "1.2.3.4"
        allow( INatAPIService ).to receive( :geoip_lookup ) do
          OpenStruct.new_recursive( results: nil )
        end
        expect( Announcement.active_in_placement( "users/dashboard#sidebar", { ip: test_ip } ) ).not_to include annc
      end
    end

    describe "ip_country with exclude_ip_countries" do
      it "excludes announcements when exclude_ip_countries matches IP country and no ip_countries are set" do
        annc = create :announcement, exclude_ip_countries: ["US"], ip_countries: []
        test_ip = "1.2.3.4"
        allow( INatAPIService ).to receive( :geoip_lookup )
          .and_return( OpenStruct.new_recursive( results: { country: "US" } ) )

        expect(
          Announcement.active_in_placement( "users/dashboard#sidebar", { ip: test_ip } )
        ).not_to include( annc )
      end

      it "excludes announcements when ip_countries overlaps exclude_ip_countries for the IP country" do
        # Both include and exclude contain "US" → exclude wins
        annc = create :announcement, ip_countries: ["US", "CA"], exclude_ip_countries: ["US"]
        test_ip = "1.2.3.4"
        allow( INatAPIService ).to receive( :geoip_lookup )
          .and_return( OpenStruct.new_recursive( results: { country: "US" } ) )

        expect(
          Announcement.active_in_placement( "users/dashboard#sidebar", { ip: test_ip } )
        ).not_to include( annc )
      end

      it "includes announcements when ip_countries includes IP country and exclude_ip_countries has no overlap" do
        # Include has "US", exclude has "PL" → allowed
        annc = create :announcement, ip_countries: ["US"], exclude_ip_countries: ["PL"]
        test_ip = "1.2.3.4"
        allow( INatAPIService ).to receive( :geoip_lookup )
          .and_return( OpenStruct.new_recursive( results: { country: "US" } ) )

        expect(
          Announcement.active_in_placement( "users/dashboard#sidebar", { ip: test_ip } )
        ).to include( annc )
      end
    end
  end
end
