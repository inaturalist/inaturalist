# frozen_string_literal: true

require "spec_helper"

describe AnnouncementImpression do
  it { is_expected.to belong_to :announcement }
  it { is_expected.to belong_to :user }

  context "with user_id" do
    before { subject.user_id = 1 }
    it do
      is_expected.to validate_uniqueness_of( :user_id ).
        scoped_to( :announcement_id, :platform_type )
    end
  end

  context "without user_id" do
    before { subject.user_id = nil }
    it do
      is_expected.to validate_uniqueness_of( :request_ip ).
        scoped_to( :announcement_id, :platform_type )
    end
  end

  describe "increment_for_announcement" do
    let( :ip ) { "127.0.0.1" }

    it "creates an impression for an announcement and user" do
      expect( AnnouncementImpression.count ).to eq 0
      announcement = Announcement.make!
      user = User.make!
      AnnouncementImpression.increment_for_announcement( announcement, user: user, request_ip: ip )
      expect( AnnouncementImpression.count ).to eq 1
      impression = AnnouncementImpression.first
      expect( impression.announcement ).to eq announcement
      expect( impression.user ).to eq user
      expect( impression.request_ip ).to eq ip
      expect( impression.impressions_count ).to eq 1
    end

    it "increments impression counts for an announcement and user" do
      expect( AnnouncementImpression.count ).to eq 0
      announcement = Announcement.make!
      user = User.make!
      3.times { AnnouncementImpression.increment_for_announcement( announcement, user: user, request_ip: ip ) }
      expect( AnnouncementImpression.count ).to eq 1
      impression = AnnouncementImpression.first
      expect( impression.announcement ).to eq announcement
      expect( impression.user ).to eq user
      expect( impression.request_ip ).to eq ip
      expect( impression.impressions_count ).to eq 3
    end

    it "creates an impression for an announcement and request_ip" do
      expect( AnnouncementImpression.count ).to eq 0
      announcement = Announcement.make!
      AnnouncementImpression.increment_for_announcement( announcement, request_ip: ip )
      expect( AnnouncementImpression.count ).to eq 1
      impression = AnnouncementImpression.first
      expect( impression.announcement ).to eq announcement
      expect( impression.user ).to be_nil
      expect( impression.request_ip ).to eq ip
      expect( impression.impressions_count ).to eq 1
    end

    it "increments impression counts for an announcement and user" do
      expect( AnnouncementImpression.count ).to eq 0
      announcement = Announcement.make!
      3.times { AnnouncementImpression.increment_for_announcement( announcement, request_ip: ip ) }
      expect( AnnouncementImpression.count ).to eq 1
      impression = AnnouncementImpression.first
      expect( impression.announcement ).to eq announcement
      expect( impression.user ).to be_nil
      expect( impression.request_ip ).to eq ip
      expect( impression.impressions_count ).to eq 3
    end

    # Regression: for logged out users the request IP is the only identifier, but
    # Logstasher.ip_from_request_env can return nil when no IP headers are present.
    # These impressions must still be counted rather than silently dropped.
    it "creates an impression for a logged out user when no request_ip is found" do
      expect( AnnouncementImpression.count ).to eq 0
      announcement = Announcement.make!
      AnnouncementImpression.increment_for_announcement( announcement, user: nil, request_ip: nil )
      expect( AnnouncementImpression.count ).to eq 1
      impression = AnnouncementImpression.first
      expect( impression.announcement ).to eq announcement
      expect( impression.user ).to be_nil
      expect( impression.request_ip ).to be_nil
      expect( impression.impressions_count ).to eq 1
    end

    it "increments impression counts for a logged out user when no request_ip is found" do
      expect( AnnouncementImpression.count ).to eq 0
      announcement = Announcement.make!
      3.times { AnnouncementImpression.increment_for_announcement( announcement, request_ip: nil ) }
      expect( AnnouncementImpression.count ).to eq 1
      impression = AnnouncementImpression.first
      expect( impression.announcement ).to eq announcement
      expect( impression.user ).to be_nil
      expect( impression.request_ip ).to be_nil
      expect( impression.impressions_count ).to eq 3
    end

    # Regression: the method advertises a :user_id option (checked on the guard and
    # branch), but it was merged in under the :user association key, which raises an
    # AssociationTypeMismatch when an id is passed instead of a User record.
    it "creates an impression when given a user_id instead of a user record" do
      expect( AnnouncementImpression.count ).to eq 0
      announcement = Announcement.make!
      user = User.make!
      AnnouncementImpression.increment_for_announcement( announcement, user_id: user.id, request_ip: ip )
      expect( AnnouncementImpression.count ).to eq 1
      impression = AnnouncementImpression.first
      expect( impression.announcement ).to eq announcement
      expect( impression.user ).to eq user
      expect( impression.request_ip ).to eq ip
      expect( impression.impressions_count ).to eq 1
    end

    it "increments impression counts when given a user_id instead of a user record" do
      expect( AnnouncementImpression.count ).to eq 0
      announcement = Announcement.make!
      user = User.make!
      3.times do
        AnnouncementImpression.increment_for_announcement( announcement, user_id: user.id, request_ip: ip )
      end
      expect( AnnouncementImpression.count ).to eq 1
      impression = AnnouncementImpression.first
      expect( impression.user ).to eq user
      expect( impression.impressions_count ).to eq 3
    end
  end
end
