# frozen_string_literal: true

require "spec_helper"

describe AnnouncementsController do
  describe "active" do
    describe "response" do
      let( :announcement ) do
        create :announcement,
          placement: Announcement::MOBILE_HOME,
          start: Time.zone.now,
          end: 1.day.from_now,
          body: "Test announcement",
          locales: ["en"],
          dismissible: true,
          clients: [Announcement::CLIENTS[Announcement::MOBILE_HOME].first]
      end

      let( :response_json ) do
        get :active, format: :json
        response.parsed_body
      end

      before do
        announcement
      end

      it "includes placement" do
        expect( response_json.first["placement"] ).to eq( announcement.placement )
      end

      it "includes id" do
        expect( response_json.first["id"] ).to eq( announcement.id )
      end

      it "includes start" do
        expect( response_json.first["start"] ).to eq( announcement.start.as_json )
      end

      it "includes end" do
        expect( response_json.first["end"] ).to eq( announcement.end.as_json )
      end

      it "includes body" do
        expect( response_json.first["body"] ).to eq( announcement.body )
      end

      it "includes locales" do
        expect( response_json.first["locales"] ).to eq( announcement.locales )
      end

      it "includes dismissible" do
        expect( response_json.first["dismissible"] ).to eq( announcement.dismissible )
      end

      it "includes clients" do
        expect( response_json.first["clients"] ).to eq( announcement.clients )
      end
    end

    describe "basic filters" do
      it "only returns announcements that are active" do
        _inactive_announcement = create :announcement, start: 1.day.from_now, end: 2.days.from_now
        active_announcement = create :announcement, start: 1.day.ago, end: 1.day.from_now
        get :active, format: :json
        expect( response.parsed_body.map {| a | a["id"] } ).to eq( [active_announcement.id] )
      end

      it "only returns announcements for the given placement" do
        _other_announcement = create :announcement, placement: Announcement::USERS_DASHBOARD
        mobile_home_announcement = create :announcement, placement: Announcement::MOBILE_HOME
        get :active, format: :json, params: { placement: Announcement::MOBILE_HOME }
        expect( response.parsed_body.map {| a | a["id"] } ).to eq( [mobile_home_announcement.id] )
      end

      it "only returns announcements for the given locale" do
        _other_announcement = create :announcement, locales: ["en"]
        spanish_announcement = create :announcement, locales: ["es"]
        get :active, format: :json, params: { locale: "es" }
        expect( response.parsed_body.map {| a | a["id"] } ).to eq( [spanish_announcement.id] )
      end

      it "falls back from regional locales to language locales" do
        _other_announcement = create :announcement, locales: ["en"]
        spanish_announcement = create :announcement, locales: ["es"]
        get :active, format: :json, params: { locale: "es-MX" }
        expect( response.parsed_body.map {| a | a["id"] } ).to eq( [spanish_announcement.id] )
      end

      it "falls back to announcements targeting no locale" do
        create :announcement, locales: ["en"]
        create :announcement, locales: ["es"]
        no_locale_announcement = create :announcement
        get :active, format: :json, params: { locale: "ja" }
        expect( response.parsed_body.map {| a | a["id"] } ).to eq( [no_locale_announcement.id] )
      end

      it "only returns announcements targeting the requested client" do
        _other_announcement = create :announcement,
          placement: Announcement::MOBILE_HOME,
          clients: [Announcement::CLIENTS[Announcement::MOBILE_HOME].first]
        announcement = create :announcement,
          placement: Announcement::MOBILE_HOME,
          clients: [Announcement::CLIENTS[Announcement::MOBILE_HOME].last]
        get :active, format: :json, params: { client: Announcement::CLIENTS[Announcement::MOBILE_HOME].last }
        expect( response.parsed_body.map {| a | a["id"] } ).to eq( [announcement.id] )
      end

      it "only returns announcements targeting the client by User-Agent" do
        request.headers["User-Agent"] = "iNaturalistReactNative"
        _other_announcement = create :announcement,
          placement: Announcement::MOBILE_HOME,
          clients: [Announcement::CLIENTS[Announcement::MOBILE_HOME].first]
        announcement = create :announcement,
          placement: Announcement::MOBILE_HOME,
          clients: [Announcement::CLIENTS[Announcement::MOBILE_HOME].last]
        get :active, format: :json
        expect( response.parsed_body.map {| a | a["id"] } ).to eq( [announcement.id] )
      end

      it "only returns mobile placements when placement is mobile" do
        _web_announcement = create :announcement, placement: Announcement::USERS_DASHBOARD
        mobile_announcement = create :announcement, placement: Announcement::MOBILE_HOME
        get :active, format: :json, params: { placement: "mobile" }
        expect( response.parsed_body.map {| a | a["id"] } ).to eq( [mobile_announcement.id] )
      end

      it "accepts multiple comma-separated placements" do
        web_announcement = create :announcement, placement: Announcement::USERS_DASHBOARD
        mobile_announcement = create :announcement, placement: Announcement::MOBILE_HOME
        get :active, format: :json, params: {
          placement: [Announcement::USERS_DASHBOARD, Announcement::MOBILE_HOME].join( "," )
        }
        annc_ids = response.parsed_body.map {| a | a["id"] }
        expect( annc_ids ).to include( mobile_announcement.id )
        expect( annc_ids ).to include( web_announcement.id )
      end

      it "accepts mobile among comma-separated placements" do
        web_announcement = create :announcement, placement: Announcement::USERS_DASHBOARD
        other_web_announcement = create :announcement, placement: Announcement::WELCOME_INDEX
        mobile_announcement = create :announcement, placement: Announcement::MOBILE_HOME
        get :active, format: :json, params: {
          placement: [Announcement::USERS_DASHBOARD, "mobile"].join( "," )
        }
        annc_ids = response.parsed_body.map {| a | a["id"] }
        expect( annc_ids ).to include( mobile_announcement.id )
        expect( annc_ids ).to include( web_announcement.id )
        expect( annc_ids ).not_to include( other_web_announcement.id )
      end
    end

    describe "for logged out" do
      it "excludes announcents that targed logged in users" do
        logged_out_announcement = create :announcement, target_logged_in: Announcement::NO
        logged_in_announcement = create :announcement, target_logged_in: Announcement::YES
        logged_any_announcement = create :announcement, target_logged_in: Announcement::ANY
        get :active, format: :json
        annc_ids = response.parsed_body.map {| a | a["id"] }
        expect( annc_ids ).to include( logged_out_announcement.id )
        expect( annc_ids ).not_to include( logged_in_announcement.id )
        expect( annc_ids ).to include( logged_any_announcement.id )
      end
    end

    describe "for logged in" do
      it "includes announcents that target logged in users" do
        sign_in create( :user )
        logged_out_announcement = create :announcement, target_logged_in: Announcement::NO
        logged_in_announcement = create :announcement, target_logged_in: Announcement::YES
        logged_any_announcement = create :announcement, target_logged_in: Announcement::ANY
        get :active, format: :json
        annc_ids = response.parsed_body.map {| a | a["id"] }
        expect( annc_ids ).not_to include( logged_out_announcement.id )
        expect( annc_ids ).to include( logged_in_announcement.id )
        expect( annc_ids ).to include( logged_any_announcement.id )
      end

      it "excludes announcements the user has dismissed" do
        user = create( :user )
        dismissed_announcement = create :announcement, dismissible: true, dismiss_user_ids: [user.id]
        active_announcement = create :announcement
        sign_in user
        get :active, format: :json
        annc_ids = response.parsed_body.map {| a | a["id"] }
        expect( annc_ids ).not_to include( dismissed_announcement.id )
        expect( annc_ids ).to include( active_announcement.id )
      end

      it "targets user by site affiliation" do
        create( :site ) unless Site.default
        user_site = create :site
        user = create :user, site: user_site
        site_announcement = create :announcement, sites: [user_site]
        other_site_announcement = create :announcement, sites: [create( :site )]
        nosite_announcement = create :announcement
        sign_in user
        get :active, format: :json
        annc_ids = response.parsed_body.map {| a | a["id"] }
        expect( annc_ids ).to include( site_announcement.id )
        expect( annc_ids ).not_to include( nosite_announcement.id )
        expect( annc_ids ).not_to include( other_site_announcement.id )
      end

      it "targets unconfirmed user" do
        unconfirmed_user = create( :user, confirmed_at: nil )
        unconfirmed_announcement = create :announcement, prefers_target_unconfirmed_users: true
        sign_in unconfirmed_user
        get :active, format: :json
        annc_ids = response.parsed_body.map {| a | a["id"] }
        expect( annc_ids ).to include( unconfirmed_announcement.id )
      end

      it "does not target confirmed users if targeting unconfirmed users" do
        unconfirmed_announcement = create :announcement, prefers_target_unconfirmed_users: true
        sign_in create( :user )
        get :active, format: :json
        annc_ids = response.parsed_body.map {| a | a["id"] }
        expect( annc_ids ).not_to include( unconfirmed_announcement.id )
      end
    end

    it "creates announcement impressions" do
      sign_in create( :user )
      announcement = create :announcement
      expect do
        get :active, format: :json
      end.to change( AnnouncementImpression, :count ).by( 1 )
      expect( AnnouncementImpression.last.announcement ).to eq( announcement )
    end
  end
end
