# frozen_string_literal: true

require "spec_helper"

describe YearStatistic do
  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to :site }
  it { is_expected.to have_many( :year_statistic_localized_shareable_images ) }

  def histogram_bucket( date, aggregation, keys )
    terms = double( "terms", buckets: keys.map {| key | { "key" => key.to_s } } )
    allow( terms ).to receive( :[] ).with( "sum_other_doc_count" ).and_return( 0 )

    bucket = double( "histogram bucket" )
    allow( bucket ).to receive( :[] ).with( "key_as_string" ).and_return( date )
    allow( bucket ).to receive( aggregation ).and_return( terms )
    bucket
  end

  def histogram_search_response( buckets )
    double( "search result",
      response: double( "response",
        aggregations: double( "aggregations",
          histogram: double( "histogram", buckets: buckets ) ) ) )
  end

  describe ".publications" do
    it "should match the YearStatistic.publications method" do
      VCR.use_cassette( "search_gbif_literature" ) do
        publications = YearStatistic.publications( 2022 )

        expect( publications[:count] ).to be_kind_of( Numeric )
        expect( publications[:url] ).to start_with( "https://www.gbif.org/resource/search" )
        expect( publications[:results] ).to be_an_instance_of( Array )
        expect(
          publications[:results][0]["_gbifDOIs"].any? do | doi |
            doi.start_with?( "gbifDOI:" )
          end
        ).to be false
      end
    end
  end

  describe "generation" do
    before do
      stub_request( :get, %r{#{INatAPIService::ENDPOINT}/observations/histogram} ).to_return(
        status: 200,
        body: '{"results": {}}'.dup,
        headers: { "Content-Type" => "application/json" }
      )
      stub_request( :get, %r{#{INatAPIService::ENDPOINT}/observations/species_counts} ).to_return(
        status: 200,
        body: '{"total_results": 0, "results": {}}'.dup,
        headers: { "Content-Type" => "application/json" }
      )
      allow( ApplicationController.helpers ).to receive( :image_url ).
        and_return "https://www.inaturalist.org/assets/bird.png"
      allow( ApplicationController.helpers ).to receive( :image_url ).
        with( "logo-small.gif" ).
        and_return "https://www.inaturalist.org/assets/logo-small.gif"
    end

    it "generate_for_year should not raise an error" do
      stub_request( :get, /gbif\.org/ ).to_return(
        status: 200,
        body: '{"results": []}'.dup,
        headers: { "Content-Type" => "application/json" }
      )
      stub_request( :get, %r{crowdin\.com.*/api/v2/projects/[^\\]+} ).to_return(
        status: 200,
        body: '{"data": {"targetLanguages":[]}}'.dup,
        headers: { "Content-Type" => "application/json" }
      )
      stub_request( :post, %r{crowdin\.com.*/top-members/export} ).to_return(
        status: 200,
        body: "{}".dup
      )
      stub_request( :get, /github\.com.*page=1/ ).to_return(
        status: 200,
        body: '[{"merged_at": "2023-11-08T17:25:09Z", "user": {"login": "foo"}}]'.dup,
        headers: { "Content-Type" => "application/json" }
      )
      stub_request( :get, /github\.com.*page=2/ ).to_return(
        status: 200,
        body: "[]".dup,
        headers: { "Content-Type" => "application/json" }
      )
      expect { YearStatistic.generate_for_year( 2023 ) }.not_to raise_error
    end
    it "generate_for_user_year should not raise an error" do
      expect { YearStatistic.generate_for_user_year( 2023, create( :user ) ) }.not_to raise_error
    end
  end

  describe "observed_species_accumulation" do
    it "queries each month in sequence and accumulates species" do
      allow( Date ).to receive( :today ).and_return( Date.new( 2008, 3, 15 ) )
      allow( YearStatistic ).to receive( :time_zone_for_options ).and_return( "UTC" )
      allow( Observation ).to receive( :params_to_elastic_query ).and_return( { filters: [] } )
      allow( Taxon ).to receive( :where ) do | conditions |
        double( "species relation", pluck: conditions[:id] )
      end

      monthly_buckets = {
        "2008-01-01" => histogram_bucket( "2008-01-01", :taxon_ids, ["11,22"] ),
        "2008-02-01" => histogram_bucket( "2008-02-01", :taxon_ids, ["22,33"] ),
        "2008-03-01" => histogram_bucket( "2008-03-01", :taxon_ids, ["33"] )
      }
      ranges = []
      allow( Observation ).to receive( :elastic_search ) do | query |
        range = query[:filters].last[:range]["created_at"]
        ranges << range
        histogram_search_response( [monthly_buckets.fetch( range[:gte] )] )
      end

      result = YearStatistic.observed_species_accumulation( verifiable: true )

      expect( Observation ).to have_received( :elastic_search ).exactly( 3 ).times
      expect( ranges ).to eq(
        [
          { gte: "2008-01-01", lt: "2008-02-01", time_zone: "UTC" },
          { gte: "2008-02-01", lt: "2008-03-01", time_zone: "UTC" },
          { gte: "2008-03-01", lt: "2008-04-01", time_zone: "UTC" }
        ]
      )
      expect( result ).to eq(
        [
          { date: "2008-01-01", accumulated_species_count: 2,
            novel_species_ids: [11, 22], species_count: 2 },
          { date: "2008-02-01", accumulated_species_count: 3,
            novel_species_ids: [33], species_count: 2 },
          { date: "2008-03-01", accumulated_species_count: 3,
            novel_species_ids: [], species_count: 1 }
        ]
      )
    end

    it "retains an empty month between populated months" do
      allow( Date ).to receive( :today ).and_return( Date.new( 2008, 3, 15 ) )
      allow( YearStatistic ).to receive( :time_zone_for_options ).and_return( "UTC" )
      allow( Observation ).to receive( :params_to_elastic_query ).
        and_return( { filters: [] } )
      allow( Taxon ).to receive( :where ) do | conditions |
        double( "species relation", pluck: conditions[:id] )
      end

      buckets_by_month = {
        "2008-01-01" => [histogram_bucket( "2008-01-01", :taxon_ids, ["11"] )],
        "2008-02-01" => [histogram_bucket( "2008-02-01", :taxon_ids, [] )],
        "2008-03-01" => [histogram_bucket( "2008-03-01", :taxon_ids, ["22"] )]
      }
      allow( Observation ).to receive( :elastic_search ) do | query |
        month = query[:filters].last[:range]["created_at"][:gte]
        histogram_search_response( buckets_by_month.fetch( month ) )
      end

      result = YearStatistic.observed_species_accumulation( verifiable: true )

      expect( result.map do | row |
        [row[:date], row[:species_count], row[:accumulated_species_count]]
      end ).to eq(
        [
          ["2008-01-01", 1, 1],
          ["2008-02-01", 0, 1],
          ["2008-03-01", 1, 2]
        ]
      )
    end

    it "queries a user's observations in 24-month chunks and returns monthly accumulation" do
      user = User.make!
      allow( Date ).to receive( :today ).and_return( Date.new( 2010, 2, 15 ) )
      allow( YearStatistic ).to receive( :time_zone_for_options ).and_return( "UTC" )
      allow( Observation ).to receive( :params_to_elastic_query ) do | params |
        expect( params[:user_id] ).to eq( user.id )
        { filters: [] }
      end
      allow( Taxon ).to receive( :where ) do | conditions |
        double( "species relation", pluck: conditions[:id] )
      end

      buckets_by_start = {
        "2008-01-01" => [
          histogram_bucket( "2008-12-01", :taxon_ids, ["11"] ),
          histogram_bucket( "2009-01-01", :taxon_ids, ["11,22"] )
        ],
        "2010-01-01" => [
          histogram_bucket( "2010-01-01", :taxon_ids, ["22,33"] ),
          histogram_bucket( "2010-02-01", :taxon_ids, ["33"] )
        ]
      }
      queries = []
      allow( Observation ).to receive( :elastic_search ) do | query |
        queries << query
        range = query[:filters].last[:range]["created_at"]
        histogram_search_response( buckets_by_start.fetch( range[:gte] ) )
      end

      result = YearStatistic.observed_species_accumulation(
        { verifiable: true, user: user }
      )

      expect( queries.map do | query |
        range = query[:filters].last[:range]["created_at"]
        [range[:gte], range[:lt]]
      end ).to eq(
        [
          ["2008-01-01", "2010-01-01"],
          ["2010-01-01", "2010-03-01"]
        ]
      )

      expect( result ).to eq(
        [
          { date: "2008-12-01", accumulated_species_count: 1,
            novel_species_ids: [11], species_count: 1 },
          { date: "2009-01-01", accumulated_species_count: 2,
            novel_species_ids: [22], species_count: 2 },
          { date: "2010-01-01", accumulated_species_count: 3,
            novel_species_ids: [33], species_count: 2 },
          { date: "2010-02-01", accumulated_species_count: 3,
            novel_species_ids: [], species_count: 1 }
        ]
      )
    end
  end

  describe "streaks" do
    it "queries each year and returns a streak crossing New Year" do
      user = User.make!
      allow( YearStatistic ).to receive( :time_zone_for_options ).and_return( "UTC" )
      allow( Observation ).to receive( :params_to_elastic_query ) {| query | query }

      buckets_by_year = {
        2024 => ( 29..31 ).map do | day |
          histogram_bucket( "2024-12-#{day}", :user_ids, [user.id] )
        end,
        2025 => [
          histogram_bucket( "2025-01-01", :user_ids, [user.id] ),
          histogram_bucket( "2025-01-02", :user_ids, [user.id] ),
          histogram_bucket( "2025-01-03", :user_ids, [] )
        ]
      }
      queries = []
      allow( Observation ).to receive( :elastic_search ) do | query |
        queries << query
        histogram_search_response( buckets_by_year.fetch( query[:d1][0, 4].to_i, [] ) )
      end

      result = YearStatistic.streaks( 2025, user: user )

      expect( Observation ).to have_received( :elastic_search ).exactly( 18 ).times
      expect( queries.map {| query | [query[:d1], query[:d2]] } ).to eq(
        ( 2008..2025 ).map {| query_year |
          ["#{query_year}-01-01", "#{query_year}-12-31"]
        }
      )
      expect( queries.last.dig( :aggs, :histogram, :date_histogram,
        :extended_bounds ) ).to eq( min: "2025-01-01", max: "2025-12-31" )
      expect( result ).to eq(
        [
          {
            user_id: user.id,
            days: 5,
            start: "2024-12-29",
            stop: "2025-01-02",
            login: user.login,
            icon_url: ApplicationController.helpers.image_url( user.icon.url( :medium ) ).
              to_s.gsub( %r{([^:])//}, "\\1/" )
          }
        ]
      )
    end

    it "does not join streaks across an empty New Year's Eve" do
      user = User.make!
      allow( YearStatistic ).to receive( :time_zone_for_options ).and_return( "UTC" )
      allow( Observation ).to receive( :params_to_elastic_query ) {| query | query }

      buckets_by_year = {
        2024 => [
          histogram_bucket( "2024-12-28", :user_ids, [user.id] ),
          histogram_bucket( "2024-12-29", :user_ids, [user.id] ),
          histogram_bucket( "2024-12-30", :user_ids, [user.id] ),
          histogram_bucket( "2024-12-31", :user_ids, [] )
        ],
        2025 => [
          histogram_bucket( "2025-01-01", :user_ids, [user.id] ),
          histogram_bucket( "2025-01-02", :user_ids, [user.id] ),
          histogram_bucket( "2025-01-03", :user_ids, [user.id] )
        ]
      }
      allow( Observation ).to receive( :elastic_search ) do | query |
        histogram_search_response(
          buckets_by_year.fetch( query[:d1][0, 4].to_i, [] )
        )
      end

      expect( YearStatistic.streaks( 2025, user: user ) ).to be_nil
    end
  end
end
