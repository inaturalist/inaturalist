require File.expand_path("../../spec_helper", __FILE__)

describe SiteStatistic do

  before :all do
    make_default_site
    OauthApplication.make!(name: "iNaturalist Android App")
    OauthApplication.make!(name: "iNaturalist iPhone App")
  end

  elastic_models( Observation, Identification, User, Project )

  before :each do
    allow( SiteStatistic ).to( receive( :generate_daily_active_user_model_data ) do
      {
        current_users: [],
        at_risk_waus: [],
        at_risk_maus: [],
        new_users: [],
        reactivated_users: [],
        reengaged_users: [],
        unengaged_users: [],
        statistic: {}
      }
    end )
    allow( UserInstallationStatistic ).to receive( :calculate_all_retention_metrics ).and_return( {} )
    allow( UserInstallationStatistic ).to receive( :update_today_installation_ids ).and_return( {} )
  end

  describe "stats_generated_for_day?" do
    it "should know when stats were generated today" do
      expect( SiteStatistic.stats_generated_for_day?).to be false
      SiteStatistic.make!
      expect( SiteStatistic.stats_generated_for_day?).to be true
    end

    it "should know when stats were generated yesterday" do
      expect( SiteStatistic.stats_generated_for_day?(1.day.ago)).to be false
      SiteStatistic.make!(created_at: 1.day.ago)
      expect( SiteStatistic.stats_generated_for_day?(1.day.ago)).to be true
    end
  end

  describe "generate_stats_for_day" do
    before do
      User.destroy_all
      Observation.destroy_all
      @user = make_curator(created_at: Time.now)
      make_user_with_role(:admin, created_at: Time.now)
      Project.make!(user: make_user_with_privilege( UserPrivilege::ORGANIZER, created_at: Time.now))
      @site = Site.make!
      observation = Observation.make!(
        taxon: Taxon.make!(rank: "species"), user: @user, site: @site)
      make_research_grade_observation(
        taxon: Taxon.make!(rank: "kingdom"), user: @user, site: @site)
    end

    it "should generate stats for today" do
      SiteStatistic.generate_stats_for_day
      data = SiteStatistic.last.data
      expect( data['identifications']['count'] ).to eq 3
      expect( data['observations']['count'] ).to eq 2
      expect( data['users']['count'] ).to eq 4
      expect( data['projects']['count'] ).to eq 1
      expect( data['taxa']['species_counts'] ).to eq 1
      # 2024-03-13: identifier stats have been disabled, so this value should be 0
      expect( data['identifier']['percent_id'] ).to eq 0
    end

    it "should generate stats for another day" do
      SiteStatistic.generate_stats_for_day(1.year.ago)
      data = SiteStatistic.last.data
      # For earlier dates we will limit queries by created_at date
      # When looking one year in the past, there should be no data
      expect( data['identifications']['count'] ).to eq 0
      expect( data['observations']['count'] ).to eq 0
      expect( data['users']['count'] ).to eq 0
      expect( data['projects']['count'] ).to eq 0
      expect( data['taxa']['species_counts'] ).to eq 0
      expect( data['identifier']['percent_id'] ).to eq 0
    end
  end

  it "should not generate stats twice in a day" do
    SiteStatistic.generate_stats_for_day
    first_stat = SiteStatistic.last
    Observation.make!
    SiteStatistic.generate_stats_for_day
    expect( first_stat ).to eq SiteStatistic.last
  end

end
