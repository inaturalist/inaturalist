# frozen_string_literal: true

require "spec_helper"

describe StatsController do
  describe "index" do
    before :all do
      make_default_site
      OauthApplication.make!( name: "iNaturalist Android App" )
      OauthApplication.make!( name: "iNaturalist iPhone App" )
      [Time.now, 1.day.ago, 1.week.ago].each do | t |
        Observation.make!( taxon: Taxon.make!( rank: "species" ),
          created_at: t )
      end
      ( 0..7 ).to_a.each do | i |
        SiteStatistic.generate_stats_for_day( i.days.ago )
        # I was hitting an error "too many open files" when running this locally,
        # but forcing garbage collection seems to help
        GC.start
      end
    end

    it "render the page HTML" do
      get :index
      expect( response.status ).to eq 200
      expect( response.content_type ).to include "text/html"
    end

    it "returns the latest stat by default" do
      get :index, format: :json
      latest_stat = SiteStatistic.order( "created_at desc" ).first
      json = JSON.parse( response.body ).first
      expect( json["created_at"] ).to eq Time.now.utc.beginning_of_day.as_json
      expect( json["data"]["identifications"]["count"] ).to eq latest_stat.data["identifications"]["count"]
      expect( json["data"]["observations"]["count"] ).to eq latest_stat.data["observations"]["count"]
      expect( json["data"]["projects"]["count"] ).to eq latest_stat.data["projects"]["count"]
      expect( json["data"]["taxa"]["species_counts"] ).to eq latest_stat.data["taxa"]["species_counts"]
      expect( json["data"]["users"]["count"] ).to eq latest_stat.data["users"]["count"]
    end

    it "render the latest stat by default" do
      get :index, format: :json, params: { start_date: 1.day.ago.to_s }
      json = JSON.parse( response.body )
      expect( json[0]["created_at"] ).to eq Time.now.utc.beginning_of_day.as_json
      expect( json[1]["created_at"] ).to eq 1.day.ago.utc.beginning_of_day.as_json
    end

    it "accepts start and end dates" do
      get :index, format: :json, params: { start_date: 7.days.ago.to_s, end_date: 6.days.ago.to_s }
      json = JSON.parse( response.body )
      expect( json[0]["created_at"] ).to eq 6.days.ago.utc.beginning_of_day.as_json
      expect( json[1]["created_at"] ).to eq 7.day.ago.utc.beginning_of_day.as_json
    end
  end

  describe "year" do
    it "sets locale based on viewed user" do
      u = User.make!( locale: "fr" )
      I18n.locale = "en"
      get :year, params: { year: Date.today.year, login: u.login }
      expect( I18n.locale ).to eq :fr
    end

    it "sets locale based on viewed user using regions" do
      u = User.make!( locale: "en-US" )
      I18n.locale = "en"
      get :year, params: { year: Date.today.year, login: u.login }
      expect( I18n.locale ).to eq :"en-US"
    end

    it "does not set the locale to use an unsupported region" do
      u = User.make!( locale: "en-ZZ" )
      I18n.locale = "fr"
      get :year, params: { year: Date.today.year, login: u.login }
      expect( I18n.locale ).to eq :en
    end

    it "does not set locale based on viewed user if there is a logged-in user" do
      u = User.make!( locale: "fr" )
      sign_in User.make!( locale: "en" )
      get :year, params: { year: Date.today.year, login: u.login }
      expect( I18n.locale ).to eq :en
    end
  end
end
