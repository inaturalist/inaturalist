require "spec_helper"

describe "ActiveRecord", "Base" do

  before(:each) { enable_elastic_indexing([ Observation ]) }
  after(:each) { disable_elastic_indexing([ Observation ]) }

  it "properly indexes the document" do
    obs = Observation.make!
    result = Observation.elastic_search( where: { id: obs.id } )
    expect( result.count ).to eq 1
    expect( result.first.class ).to eq Elasticsearch::Model::Response::Result
    expect( result.first.id.to_i ).to eq obs.id
    expect( Time.parse(result.first.created_at).round ).to eq obs.created_at.round
    expect( result.first.user.login ).to eq obs.user.login
  end

  it "properly deletes the document" do
    obs = Observation.make!
    expect( Observation.elastic_search( where: { id: obs.id } ).count ).to eq 1
    obs.destroy
    expect( Observation.elastic_search( where: { id: obs.id } ).count ).to eq 0
  end

  describe "elastic_search" do
    it "searches for match_all: { } as a wildcard query" do
      expect(Observation.__elasticsearch__).to receive(:search).with(
        { query: { match_all: { } } }).and_return(true)
      Observation.elastic_search( )
    end

    it "adds matches to the query" do
      expect(Observation.__elasticsearch__).to receive(:search).with(
        { query: { bool: {
          must: [ { match: { id: 5 } } ] } } } ).and_return(true)
      Observation.elastic_search(where: { id: 5 })
    end

    it "adds terms matches to the query" do
      expect(Observation.__elasticsearch__).to receive(:search).with(
        { query: { bool: {
          must: [ { terms: { id: [ 1, 3 ] } } ] } } } ).and_return(true)
      Observation.elastic_search(where: { id: [ 1, 3] })
    end

    it "adds envelope filters" do
      expect(Observation.__elasticsearch__).to receive(:search).with(
        { query: { filtered: { query: { match_all: { } },
          filter: { bool: { must: [ { geo_shape: { geojson: { shape: {
            type: "envelope", coordinates: [[-180, -90], [180, 88]]}}}}]}}}}}).and_return(true)
      Observation.elastic_search(filters: [ { envelope: { nelat: 88 } } ])
    end

    it "adds place filters" do
      place = Place.make!
      expect(Observation.__elasticsearch__).to receive(:search).with(
        { query: { filtered: { query: { match_all: { } },
          filter: { bool: { must: [ { geo_shape: { geojson: { indexed_shape: {
            id: place.id, type: "place", index: "places", path: "geometry_geojson"
          }}}}]}}}}}).and_return(true)
      Observation.elastic_search(filters: [ { place: place } ])
    end

    it "adds sorts to the query" do
      expect(Observation.__elasticsearch__).to receive(:search).with(
        { query: { match_all: { } },
          sort: { score: :desc } }).and_return(true)
      Observation.elastic_search(sort: { score: :desc })
    end

    it "allows certain fields to be specified" do
      expect(Observation.__elasticsearch__).to receive(:search).with(
        { query: { match_all: { } },
          fields: [ :id, :description ] }).and_return(true)
      Observation.elastic_search(fields: [ :id, :description ])
    end

    it "adds aggregations to the query" do
      expect(Observation.__elasticsearch__).to receive(:search).with(
        { query: { match_all: { } },
          aggs: { colors: { terms: {
            field: :"colors.id", size: 10 } } } }).and_return(true)
      Observation.elastic_search(aggregate: { colors: { "colors.id": 10 } } )
    end
  end

  describe "elastic_paginate" do
    it "returns a WillPaginate collection" do
      expect(Observation.elastic_paginate).to be_a WillPaginate::Collection
    end
  end

end
