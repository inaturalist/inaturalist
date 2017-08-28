require File.expand_path("../../spec_helper", __FILE__)

describe SiteStatistic do

  before :all do
    make_default_site
    OauthApplication.make!(name: "iNaturalist Android App")
    OauthApplication.make!(name: "iNaturalist iPhone App")
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
    before :all do
      User.destroy_all
      Observation.destroy_all
      @user = make_curator(created_at: Time.now)
      make_user_with_role(:admin, created_at: Time.now)
      Project.make!(user: User.make!(created_at: Time.now))
      @site = Site.make!
      observation = Observation.make!(
        taxon: Taxon.make!(rank: "species"), user: @user, site: @site)
      make_research_grade_observation(
        taxon: Taxon.make!(rank: "kingdom"), user: @user, site: @site)
    end

    it "should generate stats for today" do
      SiteStatistic.generate_stats_for_day
      @stat = SiteStatistic.last.data
      expect( @stat['identifications']['count'] ).to eq 3
      expect( @stat['observations']['count'] ).to eq 2
      expect( @stat['users']['count'] ).to eq 4
      expect( @stat['projects']['count'] ).to eq 1
      expect( @stat['taxa']['species_counts'] ).to eq 1
      expect( @stat['identifier']['percent_id'] ).to eq 1
    end

    it "should generate stats for another day" do
      SiteStatistic.generate_stats_for_day(1.year.ago)
      @stat = SiteStatistic.last.data
      # For earlier dates we will limit queries by created_at date
      # When looking one year in the past, there should be no data
      expect( @stat['identifications']['count'] ).to eq 0
      expect( @stat['observations']['count'] ).to eq 0
      expect( @stat['users']['count'] ).to eq 0
      expect( @stat['projects']['count'] ).to eq 0
      expect( @stat['taxa']['species_counts'] ).to eq 0
      expect( @stat['identifier']['percent_id'] ).to eq 0
    end
  end

  it "should not generate stats twice in a day" do
    SiteStatistic.generate_stats_for_day
    first_stat = SiteStatistic.last
    Observation.make!
    SiteStatistic.generate_stats_for_day
    expect( first_stat).to eq SiteStatistic.last
  end

end