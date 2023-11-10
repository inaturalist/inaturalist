# frozen_string_literal: true

require "spec_helper"

describe YearStatistic do
  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to :site }
  it { is_expected.to have_many( :year_statistic_localized_shareable_images ) }
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
      with( "yir-background.png" ).
      and_return(
        "https://www.inaturalist.org/assets/yir-background-53da44f111e173166d77ae72876317451138608172da76c1a176504261a36397.png"
      )
    allow( ApplicationController.helpers ).to receive( :image_url ).
      with( "logo-small.gif" ).
      and_return "https://www.inaturalist.org/assets/logo-small.gif"
    allow( ApplicationController.helpers ).to receive( :image_url ).
      with( "bird.png" ).
      and_return "https://www.inaturalist.org/assets/bird.png"
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
