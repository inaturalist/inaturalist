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
  end
end
