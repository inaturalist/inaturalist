require File.expand_path("../../spec_helper", __FILE__)

describe SiteStatistic do

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
      expect( @stat ).to eq({
        "identifications" => { "count"=> 3, "last_7_days" => 3, "today" => 3 },
        "observations" => { "count" => 2, "research_grade" => 1,
          "last_7_days" => 2, "today" => 2 },
        "users" => { "count" => 4, "curators" => 2, "admins" => 1,
          # users are made 5 days ago by default, the extra one comes from the identification on the RG obserbation
          "active" => 2, "last_7_days" => 4, "today" => 3 }, 
        "projects" => { "count" => 1, "last_7_days" => 1, "today" => 1 },
        "taxa" => {
          "species_counts" => 1,
          "species_counts_by_site" => { @site.name => 1 },
          "count_by_rank" => { "species" => 1, "kingdom" => 1 }
        }
      })
    end

    it "should generate stats for another day" do
      SiteStatistic.generate_stats_for_day(1.year.ago)
      @stat = SiteStatistic.last.data
      # For earlier dates we will limit queries by created_at date
      # When looking one year in the past, there should be no data
      expect( @stat ).to eq({
        "identifications" => { "count"=> 0, "last_7_days" => 0, "today" => 0 },
        "observations" => { "count" => 0, "research_grade" => 0,
          "last_7_days" => 0, "today" => 0 },
        "users" => { "count" => 0, "curators" => 0, "admins" => 0,
          "active" => 0, "last_7_days" => 0, "today" => 0 },
        "projects" => { "count" => 0, "last_7_days" => 0, "today" => 0 },
        "taxa" => {
          "species_counts" => 0,
          "species_counts_by_site" => { },
          "count_by_rank" => { }
        }
      })
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