# frozen_string_literal: true

require "spec_helper"

describe YearStatistic do
  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to :site }
  it { is_expected.to have_many( :year_statistic_localized_shareable_images ) }

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
end

describe YearStatistic, "generation" do
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
      with( "yir-background.png" ).
      and_return(
        "https://www.inaturalist.org/assets/yir-background.png"
      )
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
    stub_request( :get, %r{crowdin\.com.*/info} ).to_return(
      status: 200,
      body: '{"languages": []}'.dup,
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
