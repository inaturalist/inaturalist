require "spec_helper"

describe "Observation Index" do
  before( :all ) do
    @starting_time_zone = Time.zone
    Time.zone = ActiveSupport::TimeZone["Samoa"]
  end
  after( :all ) { Time.zone = @starting_time_zone }

  it "as_indexed_json should return a hash" do
    o = Observation.make!
    json = o.as_indexed_json
    expect( json ).to be_a Hash
  end

  it "sets location based on private coordinates if exist" do
    o = Observation.make!(latitude: 3.0, longitude: 4.0)
    o.update_attributes(private_latitude: 1.0, private_longitude: 2.0)
    json = o.as_indexed_json
    expect( json[:location] ).to eq "1.0,2.0"
  end

  it "sets location based on public coordinates if there are no private" do
    o = Observation.make!(latitude: 3.0, longitude: 4.0)
    json = o.as_indexed_json
    expect( json[:location] ).to eq "3.0,4.0"
  end

  it "indexes created_at based on observation time zone" do
    o = Observation.make!(created_at: "2014-12-31 20:00:00 -0800")
    json = o.as_indexed_json
    expect( json[:created_at].day ).to eq 31
    expect( json[:created_at].month ).to eq 12
    expect( json[:created_at].year ).to eq 2014
  end

  it "indexes created_at_details based on observation time zone" do
    o = Observation.make!(created_at: "2014-12-31 20:00:00 -0800")
    json = o.as_indexed_json
    expect( json[:created_at_details][:day] ).to eq 31
    expect( json[:created_at_details][:month] ).to eq 12
    expect( json[:created_at_details][:year] ).to eq 2014
  end

  describe "params_to_elastic_query" do
    it "returns nil when ES can't handle the params" do
      expect( Observation.params_to_elastic_query(
        Observation::NON_ELASTIC_ATTRIBUTES.first => "anything") ).to be nil
    end

    it "doesn't apply a site filter unless the site wants one" do
      s = Site.make!(preferred_site_observations_filter: nil)
      expect( Observation.params_to_elastic_query({ }, site: s) ).to include( where: { } )
    end

    it "filters by site_id" do
      s = Site.make!(preferred_site_observations_filter: Site::OBSERVATIONS_FILTERS_SITE)
      expect( Observation.params_to_elastic_query({ }, site: s) ).to include(
        where: { "site_id" => s.id } )
    end

    it "filters by site place" do
      s = Site.make!(preferred_site_observations_filter: Site::OBSERVATIONS_FILTERS_PLACE, place: Place.make!)
      expect( Observation.params_to_elastic_query({ }, site: s) ).to include(
        where: { "place_ids" => s.place } )
    end

    it "filters by site bounding box" do
      s = Site.make!(preferred_site_observations_filter: Site::OBSERVATIONS_FILTERS_BOUNDING_BOX,
        preferred_geo_nelat: 55, preferred_geo_nelng: 66, preferred_geo_swlat: 77, preferred_geo_swlng: 88)
      expect( Observation.params_to_elastic_query({ }, site: s) ).to include(
        filters: [{ envelope: { geojson: { nelat: "55", nelng: "66", swlat: "77", swlng: "88", user: nil } } }] )
    end

    it "queries names" do
      expect( Observation.params_to_elastic_query({ q: "s", search_on: "names" }) ).to include(
        where: { "multi_match" => { query: "s", operator: "and", fields: [ "taxon.names.name" ] } } )
    end

    it "queries tags" do
      expect( Observation.params_to_elastic_query({ q: "s", search_on: "tags" }) ).to include(
        where: { "multi_match" => { query: "s", operator: "and", fields: [ :tags ] } } )
    end

    it "queries descriptions" do
      expect( Observation.params_to_elastic_query({ q: "s", search_on: "description" }) ).to include(
        where: { "multi_match" => { query: "s", operator: "and", fields: [ :description ] } } )
    end

    it "queries places" do
      expect( Observation.params_to_elastic_query({ q: "s", search_on: "place" }) ).to include(
        where: { "multi_match" => { query: "s", operator: "and", fields: [ :place_guess ] } } )
    end

    it "queries all fields by default" do
      expect( Observation.params_to_elastic_query({ q: "s" }) ).to include(
        where: { "multi_match" => { query: "s", operator: "and", fields:
          [ "taxon.names.name", :tags, :description, :place_guess ] } } )
    end

    it "filters by user and user_id" do
      expect( Observation.params_to_elastic_query({ user: 1 }) ).to include(
        where: { "user.id" => 1 } )
      expect( Observation.params_to_elastic_query({ user_id: 1 }) ).to include(
        where: { "user.id" => 1 } )
    end

    it "filters by rank" do
      expect( Observation.params_to_elastic_query({ rank: "species" }) ).to include(
        where: { "taxon.rank" => "species" } )
    end

    it "filters by taxon_id" do
      expect( Observation.params_to_elastic_query({ observations_taxon: 1 }) ).to include(
        where: { "taxon.ancestor_ids" => 1 } )
    end

    it "filters by taxon_ids" do
      expect( Observation.params_to_elastic_query({ observations_taxon_ids: [ 1, 2 ] }) ).to include(
        where: { "taxon.ancestor_ids" => [ 1, 2 ] } )
    end

    it "filters by created_on year" do
      expect( Observation.params_to_elastic_query({ created_on: "2005" }) ).to include(
        where: { "created_at_details.year" => 2005 } )
    end

    it "filters by created_on year and month" do
      expect( Observation.params_to_elastic_query({ created_on: "2005-01" }) ).to include(
        where: { "created_at_details.year" => 2005, "created_at_details.month" => 1 } )
    end

    it "filters by created_on year and month and day" do
      expect( Observation.params_to_elastic_query({ created_on: "2005-01-02" }) ).to include(
        where: { "created_at_details.year" => 2005, "created_at_details.month" => 1,
          "created_at_details.day" => 2 } )
    end

    it "filters by project" do
      expect( Observation.params_to_elastic_query({ project: 1 }) ).to include(
        where: { "project_ids" => [ 1 ] } )
    end

    it "filters by lrank" do
      expect( Observation.params_to_elastic_query({ lrank: "species" }) ).to include(
        where: { "range" => { "taxon.rank_level" => { from: 10, to: 100 } } } )
    end

    it "filters by hrank" do
      expect( Observation.params_to_elastic_query({ hrank: "family" }) ).to include(
        where: { "range" => { "taxon.rank_level" => { from: 0, to: 30 } } } )
    end

    it "filters by lrank and hrank" do
      expect( Observation.params_to_elastic_query({ lrank: "species", hrank: "family" }) ).to include(
        where: { "range" => { "taxon.rank_level" => { from: 10, to: 30 } } } )
    end

    it "does not filter by reviewed without a user" do
      u = User.make!
      expect( Observation.params_to_elastic_query({ reviewed: "true" }) ).to include( where: { } )
    end

    it "filters by reviewed true" do
      u = User.make!
      expect( Observation.params_to_elastic_query({ reviewed: "true" }, current_user: u) ).to include(
        where: { "reviewed_by" => u.id } )
    end

    it "filters by reviewed false" do
      u = User.make!
      expect( Observation.params_to_elastic_query({ reviewed: "false" }, current_user: u) ).to include(
        filters: [ { not: { term: { reviewed_by: u.id } } } ] )
    end

  end
end
