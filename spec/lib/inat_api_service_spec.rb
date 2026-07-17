# frozen_string_literal: true

require "spec_helper"

describe INatAPIService do
  before :each do
    # stubbing HEAD
    stub_request( :head, /#{INatAPIService::ENDPOINT}/ ).
      to_return( status: 200, body: "", headers: {} )
    # stubbing GET
    stub_request( :get, /#{INatAPIService::ENDPOINT}/ ).
      to_return( status: 200, body: +'{"total_results": 9 }',
        headers: { "Content-Type" => "application/json" } )
    # stubbing GET V2
    stub_request( :get, /#{INatAPIService::ENDPOINT_V2}/ ).
      to_return( status: 200, body: +'{"page": 2 }',
        headers: { "Content-Type" => "application/json" } )
    # stubbing POST V2
    stub_request( :post, /#{INatAPIService::ENDPOINT_V2}/ ).
      to_return( status: 200, body: +'{"per_page": 2 }',
        headers: { "Content-Type" => "application/json" } )
  end

  it "fetches observations" do
    result = INatAPIService.observations
    expect( result.total_results ).to eq 9
    expect(
      a_request( :get, "#{INatAPIService::ENDPOINT}/observations" )
    ).to have_been_made
  end

  it "can use API v2 with custom endpoint methods" do
    result = INatAPIService.observations( {}, v2: true )
    expect( result.page ).to eq 2
    expect(
      a_request( :get, "#{INatAPIService::ENDPOINT_V2}/observations" )
    ).to have_been_made
  end

  it "fetches observations_observers" do
    result = INatAPIService.observations_observers
    expect( result.total_results ).to eq 9
    expect(
      a_request( :get, "#{INatAPIService::ENDPOINT}/observations/observers" )
    ).to have_been_made
  end

  it "fetches observations_species_counts" do
    result = INatAPIService.observations_species_counts
    expect( result.total_results ).to eq 9
    expect(
      a_request( :get, "#{INatAPIService::ENDPOINT}/observations/species_counts" )
    ).to have_been_made
  end

  it "calls custom endpoints" do
    result = INatAPIService.get( "/users" )
    expect( result.total_results ).to eq 9
    expect(
      a_request( :get, "#{INatAPIService::ENDPOINT}/users" )
    ).to have_been_made
  end

  it "calls custom endpoints with API v2" do
    result = INatAPIService.get( "/users", {}, v2: true )
    expect( result.page ).to eq 2
    expect(
      a_request( :get, "#{INatAPIService::ENDPOINT_V2}/users" )
    ).to have_been_made
  end

  describe "authorization" do
    let( :custom_jwt ) { "CUSTOM_JWT" }

    it "allows authorization to be set explicitly" do
      result = INatAPIService.get( "/users", {}, v2: true, authorization: custom_jwt )
      expect( result.page ).to eq 2
      expect(
        a_request( :get, "#{INatAPIService::ENDPOINT_V2}/users" ).with(
          headers: { Authorization: custom_jwt }
        )
      ).to have_been_made
    end

    it "allows authorization to be set explicitly with POST override" do
      fields = {}
      ( 0..200 ).to_a.each do | index |
        fields["field#{index}"] = true
      end
      result = INatAPIService.get(
        "/users", { fields: fields }, v2: true, authorization: custom_jwt
      )
      expect( result.per_page ).to eq 2
      expect(
        a_request( :post, "#{INatAPIService::ENDPOINT_V2}/users" ).with(
          headers: {
            Authorization: custom_jwt,
            "X-HTTP-Method-Override": "GET"
          }
        )
      ).to have_been_made
    end

    it "allows authorization to be set via user instance" do
      user = User.make
      allow( user ).to receive( :api_token ).and_return( custom_jwt )
      result = INatAPIService.get( "/users", { authenticate: user }, v2: true )
      expect( result.page ).to eq 2
      expect(
        a_request( :get, "#{INatAPIService::ENDPOINT_V2}/users" ).with(
          headers: { Authorization: custom_jwt }
        )
      ).to have_been_made
    end

    it "allows authorization to be set via user instance with POST override" do
      user = User.make
      allow( user ).to receive( :api_token ).and_return( custom_jwt )
      fields = {}
      ( 0..200 ).to_a.each do | index |
        fields["field#{index}"] = true
      end
      result = INatAPIService.get( "/users", { fields: fields, authenticate: user }, v2: true )
      expect( result.per_page ).to eq 2
      expect(
        a_request( :post, "#{INatAPIService::ENDPOINT_V2}/users" ).with(
          headers: {
            Authorization: custom_jwt,
            "X-HTTP-Method-Override": "GET"
          }
        )
      ).to have_been_made
    end
  end

  describe "fields" do
    it "leaves a fields string alone" do
      fields = "field1"
      result = INatAPIService.get( "/users", { fields: fields }, v2: true )
      expect( result.page ).to eq 2
      expect(
        a_request( :get, "#{INatAPIService::ENDPOINT_V2}/users" ).with(
          query: { fields: fields }
        )
      ).to have_been_made
    end

    it "concatenates a fields array with commas" do
      fields = ["field1", "field2"]
      result = INatAPIService.get( "/users", { fields: fields }, v2: true )
      expect( result.page ).to eq 2
      expect(
        a_request( :get, "#{INatAPIService::ENDPOINT_V2}/users" ).with(
          query: { fields: fields.join( "," ) }
        )
      ).to have_been_made
    end

    it "encodes a fields hash with Rison" do
      fields = { field1: true, field2: true }
      result = INatAPIService.get( "/users", { fields: fields }, v2: true )
      expect( result.page ).to eq 2
      expect(
        a_request( :get, "#{INatAPIService::ENDPOINT_V2}/users" ).with(
          query: { fields: Rison.dump( fields ) }
        )
      ).to have_been_made
    end

    it "uses a post when many fields are defined" do
      fields = {}
      ( 0..200 ).to_a.each do | index |
        fields["field#{index}"] = true
      end
      result = INatAPIService.get( "/users", { fields: fields }, v2: true )
      expect( result.per_page ).to eq 2
      expect(
        a_request( :post, "#{INatAPIService::ENDPOINT_V2}/users" ).with(
          body: { fields: fields },
          headers: { "X-HTTP-Method-Override": "GET" }
        )
      ).to have_been_made
    end
  end
end
