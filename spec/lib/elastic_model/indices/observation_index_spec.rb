require "spec_helper"

describe "Observation Index" do
  before( :all ) do
    @starting_time_zone = Time.zone
    Time.zone = ActiveSupport::TimeZone["Samoa"]
    load_test_taxa
  end
  after( :all ) { Time.zone = @starting_time_zone }
  before(:each) { enable_elastic_indexing( Observation ) }
  after(:each) { disable_elastic_indexing( Observation ) }

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

  it "sorts photos by position and ID" do
    o = Observation.make!(latitude: 3.0, longitude: 4.0)
    p3 = LocalPhoto.make!
    p1 = LocalPhoto.make!
    p2 = LocalPhoto.make!
    p4 = LocalPhoto.make!
    p5 = LocalPhoto.make!
    make_observation_photo(photo: p1, observation: o, position: 1)
    make_observation_photo(photo: p2, observation: o, position: 2)
    make_observation_photo(photo: p3, observation: o, position: 3)
    # these without a position will be last in order of creation
    make_observation_photo(photo: p4, observation: o)
    make_observation_photo(photo: p5, observation: o)
    o.reload
    json = o.as_indexed_json
    expect( json[:photos][0][:id] ).to eq p1.id
    expect( json[:photos][1][:id] ).to eq p2.id
    expect( json[:photos][2][:id] ).to eq p3.id
    expect( json[:photos][3][:id] ).to eq p4.id
    expect( json[:photos][4][:id] ).to eq p5.id
  end

  it "uses private_latitude/longitude to create private_geojson" do
    o = Observation.make!
    o.update_columns(private_latitude: 3.0, private_longitude: 4.0, private_geom: nil)
    o.reload
    expect( o.private_geom ).to be nil
    json = o.as_indexed_json
    expect( json[:private_geojson][:coordinates] ).to eq [4.0, 3.0]
  end

  it "sets taxon globally threatened" do
    o = Observation.make!(taxon: Taxon.make!)
    expect( o.as_indexed_json[:taxon][:threatened] ).to be false
    ConservationStatus.make!(place: nil, taxon: o.taxon,
      status: Taxon::IUCN_NEAR_THREATENED)
    o.reload
    expect( o.as_indexed_json[:taxon][:threatened] ).to be true
  end

  it "sets taxon threatened in a place" do
    present_place = make_place_with_geom(wkt: "MULTIPOLYGON(((0 0,0 1,1 1,1 0,0 0)))")
    absent_place = make_place_with_geom(wkt: "MULTIPOLYGON(((2 2,2 3,3 3,3 2,2 2)))")
    o = Observation.make!(taxon: Taxon.make!, latitude: present_place.latitude,
      longitude: present_place.longitude)
    expect( o.as_indexed_json[:taxon][:threatened] ).to be false
    cs = ConservationStatus.make!(place: absent_place, taxon: o.taxon,
      status: Taxon::IUCN_NEAR_THREATENED)
    o.reload
    expect( o.as_indexed_json[:taxon][:threatened] ).to be false
    cs.update_attributes(place: present_place)
    o.reload
    expect( o.as_indexed_json[:taxon][:threatened] ).to be true
  end

  it "sets taxon introduced" do
    place = make_place_with_geom
    o = Observation.make!(taxon: Taxon.make!, latitude: place.latitude,
      longitude: place.longitude)
    expect( o.as_indexed_json[:taxon][:introduced] ).to be false
    expect( o.as_indexed_json[:taxon][:native] ).to be false
    expect( o.as_indexed_json[:taxon][:endemic] ).to be false
    cs = ListedTaxon.make!(place: place, taxon: o.taxon, list: place.check_list,
      establishment_means: "introduced")
    o.reload
    expect( o.as_indexed_json[:taxon][:introduced] ).to be true
    expect( o.as_indexed_json[:taxon][:native] ).to be false
    expect( o.as_indexed_json[:taxon][:endemic] ).to be false
  end

  it "sets taxon native" do
    place = make_place_with_geom
    o = Observation.make!(taxon: Taxon.make!, latitude: place.latitude,
      longitude: place.longitude)
    expect( o.as_indexed_json[:taxon][:introduced] ).to be false
    expect( o.as_indexed_json[:taxon][:native] ).to be false
    expect( o.as_indexed_json[:taxon][:endemic] ).to be false
    cs = ListedTaxon.make!(place: place, taxon: o.taxon, list: place.check_list,
      establishment_means: "native")
    o.reload
    expect( o.as_indexed_json[:taxon][:introduced] ).to be false
    expect( o.as_indexed_json[:taxon][:native] ).to be true
    expect( o.as_indexed_json[:taxon][:endemic] ).to be false
  end

  it "sets taxon endemic" do
    place = make_place_with_geom
    o = Observation.make!(taxon: Taxon.make!, latitude: place.latitude,
      longitude: place.longitude)
    expect( o.as_indexed_json[:taxon][:introduced] ).to be false
    expect( o.as_indexed_json[:taxon][:native] ).to be false
    expect( o.as_indexed_json[:taxon][:endemic] ).to be false
    cs = ListedTaxon.make!(place: place, taxon: o.taxon, list: place.check_list,
      establishment_means: "endemic")
    o.reload
    expect( o.as_indexed_json[:taxon][:introduced] ).to be false
    expect( o.as_indexed_json[:taxon][:native] ).to be true
    expect( o.as_indexed_json[:taxon][:endemic] ).to be true
  end

  it "indexes identifications" do
    o = Observation.make!
    Identification.where(observation_id: o.id).destroy_all
    5.times{ Identification.make!(observation: o) }
    json = o.as_indexed_json
    expect( json[:non_owner_ids].length ).to eq 5
    expect( json[:non_owner_ids].first ).to eq o.identifications.first.
      as_indexed_json(no_details: true)
  end

  it "indexes owners_identification_from_vision" do
    o = Observation.make!( taxon: Taxon.make!, owners_identification_from_vision: true )
    expect( o.owners_identification_from_vision ).to be true
    json = o.as_indexed_json
    expect( json[:owners_identification_from_vision] ).to be true
  end

  it "indexes project observation curator_coordinate_access in bulk" do
    po = ProjectObservation.make!( prefers_curator_coordinate_access: true )
    json = po.observation.as_indexed_json
    expect( json[:project_observations][0][:curator_coordinate_access] ).to be true
    expect( json[:project_observations][0][:curator_coordinate_access] ).not_to be_nil
  end

  it "indexes project observation curator_coordinate_access in bulk" do
    po = ProjectObservation.make!( prefers_curator_coordinate_access: true )
    expect { Observation.elastic_index! }.not_to raise_error
  end

  describe "params_to_elastic_query" do
    it "returns nil when ES can't handle the params" do
      expect( Observation.params_to_elastic_query(
        Observation::NON_ELASTIC_ATTRIBUTES.first => "anything") ).to be nil
    end

    it "filters by project rules" do
      project = Project.make!
      rule = ProjectObservationRule.make!(operator: "identified?", ruler: project)
      expect( Observation.params_to_elastic_query(apply_project_rules_for: project.id)).
        to include( filters: [{ exists: { field: "taxon" } }])
    end

    it "filters by list taxa" do
      list = List.make!
      lt1 = ListedTaxon.make!(list: list, taxon: Taxon.make!)
      lt2 = ListedTaxon.make!(list: list, taxon: Taxon.make!)
      expect( Observation.params_to_elastic_query(list_id: list.id)).
        to include( filters: [{ terms: { "taxon.ancestor_ids" => [ lt1.taxon_id, lt2.taxon_id ] } }])
    end

    it "doesn't apply a site filter unless the site wants one" do
      s = Site.make!(preferred_site_observations_filter: nil)
      expect( Observation.params_to_elastic_query({ }, site: s) ).to include( filters: [ ] )
    end

    it "queries names" do
      expect( Observation.params_to_elastic_query({ q: "s", search_on: "names" }) ).to include(
        filters: [ { multi_match:
          { query: "s", operator: "and", fields: [ "taxon.names.name" ] } } ] )
    end

    it "queries tags" do
      expect( Observation.params_to_elastic_query({ q: "s", search_on: "tags" }) ).to include(
        filters: [ { multi_match:
          { query: "s", operator: "and", fields: [ :tags ] } } ] )
    end

    it "queries descriptions" do
      expect( Observation.params_to_elastic_query({ q: "s", search_on: "description" }) ).to include(
        filters: [ { multi_match:
          { query: "s", operator: "and", fields: [ :description ] } } ] )
    end

    it "queries places" do
      expect( Observation.params_to_elastic_query({ q: "s", search_on: "place" }) ).to include(
        filters: [ { multi_match:
          { query: "s", operator: "and", fields: [ :place_guess ] } } ] )
    end

    it "queries all fields by default" do
      expect( Observation.params_to_elastic_query({ q: "s" }) ).to include(
        filters: [ { multi_match:
          { query: "s", operator: "and",
            fields: [ "taxon.names.name", :tags, :description, :place_guess ] } } ] )
    end

    it "filters by param values" do
      [ { http_param: :rank, es_field: "taxon.rank" },
        { http_param: :sound_license, es_field: "sounds.license_code" },
        { http_param: :observed_on_day, es_field: "observed_on_details.day" },
        { http_param: :observed_on_month, es_field: "observed_on_details.month" },
        { http_param: :observed_on_year, es_field: "observed_on_details.year" },
        { http_param: :place_id, es_field: "place_ids" },
        { http_param: :site_id, es_field: "site_id" }
      ].each do |filter|
        # single values
        expect( Observation.params_to_elastic_query({
          filter[:http_param] => "thevalue" }) ).to include(
            filters: [ { terms: { filter[:es_field] => [ "thevalue" ] } } ] )
        # multiple values
        expect( Observation.params_to_elastic_query({
          filter[:http_param] => [ "value1", "value2" ] }) ).to include(
            filters: [ { terms: { filter[:es_field] => [ "value1", "value2" ] } } ] )
      end
    end

    it "filters by boolean params" do
      [ { http_param: :introduced, es_field: "taxon.introduced" },
        { http_param: :threatened, es_field: "taxon.threatened" },
        { http_param: :native, es_field: "taxon.native" },
        { http_param: :endemic, es_field: "taxon.endemic" },
        { http_param: :id_please, es_field: "id_please" },
        { http_param: :out_of_range, es_field: "out_of_range" },
        { http_param: :mappable, es_field: "mappable" },
        { http_param: :captive, es_field: "captive" }
      ].each do |filter|
        expect( Observation.params_to_elastic_query({
          filter[:http_param] => "true" }) ).to include(
            filters: [ { term: { filter[:es_field] => true } } ] )
        expect( Observation.params_to_elastic_query({
          filter[:http_param] => "false" }) ).to include(
            filters: [ { term: { filter[:es_field] => false } } ] )
      end
    end

    it "filters by presence of attributes" do
      [ { http_param: :with_photos, es_field: "photos.url" },
        { http_param: :with_sounds, es_field: "sounds" },
        { http_param: :with_geo, es_field: "geojson" },
        { http_param: :identified, es_field: "taxon" },
      ].each do |filter|
        f = { exists: { field: filter[:es_field] } }
        expect( Observation.params_to_elastic_query({
          filter[:http_param] => "true" }) ).to include(
            filters: [ f ] )
        expect( Observation.params_to_elastic_query({
          filter[:http_param] => "false" }) ).to include(
            inverse_filters: [ f ] )
      end
    end

    it "filters by verifiable true" do
      expect( Observation.params_to_elastic_query({ verifiable: "true" }) ).to include(
        filters: [ { terms: { quality_grade: [ "research", "needs_id" ] } } ] )
    end

    it "filters by verifiable false" do
      expect( Observation.params_to_elastic_query({ verifiable: "false" }) ).to include(
        filters: [ { not: { terms: { quality_grade: [ "research", "needs_id" ] } } } ] )
    end

    it "filters by site_id" do
      s = Site.make!(preferred_site_observations_filter: Site::OBSERVATIONS_FILTERS_SITE)
      expect( Observation.params_to_elastic_query({ }, site: s) ).to include(
      filters: [ { terms: { "site_id" => [ s.id ] } } ] )
    end

    it "filters by site place" do
      s = Site.make!(preferred_site_observations_filter: Site::OBSERVATIONS_FILTERS_PLACE, place: Place.make!)
      expect( Observation.params_to_elastic_query({ }, site: s) ).to include(
        filters: [ { terms: { "place_ids" => [ s.place.id ] } } ] )
    end

    it "filters by site bounding box" do
      s = Site.make!(preferred_site_observations_filter: Site::OBSERVATIONS_FILTERS_BOUNDING_BOX,
        preferred_geo_nelat: 55, preferred_geo_nelng: 66, preferred_geo_swlat: 77, preferred_geo_swlng: 88)
      expect( Observation.params_to_elastic_query({ }, site: s) ).to include(
        filters: [{ envelope: { geojson: { nelat: "55", nelng: "66", swlat: "77", swlng: "88", user: nil } } }] )
    end

    it "filters by user and user_id" do
      expect( Observation.params_to_elastic_query({ user: 1 }) ).to include(
        filters: [ { terms: { "user.id" => [ 1 ] } } ] )
      expect( Observation.params_to_elastic_query({ user_id: 1 }) ).to include(
        filters: [ { terms: { "user.id" => [ 1 ] } } ] )
    end

    it "filters by taxon_id" do
      expect( Observation.params_to_elastic_query({ observations_taxon: 1 }) ).to include(
        filters: [ { term: { "taxon.ancestor_ids" => 1 } } ] )
    end

    it "filters by taxon_ids" do
      expect( Observation.params_to_elastic_query({ observations_taxon_ids: [ 1, 2 ] }) ).to include(
        filters: [ { terms: { "taxon.ancestor_ids" => [ 1, 2 ] } } ] )
    end

    it "filters by license" do
      expect( Observation.params_to_elastic_query({ license: "any" }) ).to include(
        filters: [ { exists: { field: "license_code" } } ] )
      expect( Observation.params_to_elastic_query({ license: "none" }) ).to include(
        inverse_filters: [ { exists: { field: "license_code" } } ] )
      expect( Observation.params_to_elastic_query({ license: "CC-BY" }) ).to include(
        filters: [ { terms: { license_code: [ "cc-by" ] } } ] )
      expect( Observation.params_to_elastic_query({ license: [ "CC-BY", "CC-BY-NC" ] }) ).to include(
        filters: [ { terms: { license_code: [ "cc-by", "cc-by-nc" ] } } ] )
    end

    it "filters by photo license" do
      expect( Observation.params_to_elastic_query({ photo_license: "any" }) ).to include(
        filters: [ { exists: { field: "photos.license_code" } } ] )
      expect( Observation.params_to_elastic_query({ photo_license: "none" }) ).to include(
        inverse_filters: [ { exists: { field: "photos.license_code" } } ] )
      expect( Observation.params_to_elastic_query({ photo_license: "CC-BY" }) ).to include(
        filters: [ { terms: { "photos.license_code" => [ "cc-by" ] } } ] )
      expect( Observation.params_to_elastic_query({ photo_license: [ "CC-BY", "CC-BY-NC" ] }) ).to include(
        filters: [ { terms: { "photos.license_code" => [ "cc-by", "cc-by-nc" ] } } ] )
    end

    it "filters by created_on year" do
      expect( Observation.params_to_elastic_query({ created_on: "2005" }) ).to include(
        filters: [ { term: { "created_at_details.year" => 2005 } } ] )
    end

    it "filters by created_on year and month" do
      expect( Observation.params_to_elastic_query({ created_on: "2005-01" }) ).to include(
        filters: [ { term: { "created_at_details.month" => 1 } },
                   { term: { "created_at_details.year" => 2005 } } ] )
    end

    it "filters by created_on year and month and day" do
      expect( Observation.params_to_elastic_query({ created_on: "2005-01-02" }) ).to include(
        filters: [ { term: { "created_at_details.day" => 2 } },
                   { term: { "created_at_details.month" => 1 } },
                   { term: { "created_at_details.year" => 2005 } } ] )
    end

    it "filters by project" do
      expect( Observation.params_to_elastic_query({ project: 1 }) ).to include(
        filters: [ { terms: { project_ids: [ 1 ] } } ] )
    end

    it "filters by pcid with a specified project" do
      expect( Observation.params_to_elastic_query({ project: 1, pcid: "yes" }) ).to include(
        filters: [
          { terms: { project_ids: [ 1 ] } },
          { terms: { project_ids_with_curator_id: [ 1 ] } } ] )
      expect( Observation.params_to_elastic_query({ project: 1, pcid: "no" }) ).to include(
        filters: [
          { terms: { project_ids: [ 1 ] } },
          { terms: { project_ids_without_curator_id: [ 1 ] } } ] )
    end

    it "filters by pcid" do
      expect( Observation.params_to_elastic_query({ pcid: "yes" }) ).to include(
        filters: [ { exists: { field: "project_ids_with_curator_id" } } ] )
      expect( Observation.params_to_elastic_query({ pcid: "no" }) ).to include(
        filters: [ { exists: { field: "project_ids_without_curator_id" } } ] )
    end

    it "filters by not_in_project" do
      p = Project.make!
      expect( Observation.params_to_elastic_query({ not_in_project: p.id }) ).to include(
        inverse_filters: [ { term: { project_ids: p.id } } ] )
    end

    it "filters by lrank" do
      expect( Observation.params_to_elastic_query({ lrank: "species" }) ).to include(
        filters: [ { range: { "taxon.rank_level" => { gte: 10, lte: 100 } } } ])
    end

    it "filters by hrank" do
      expect( Observation.params_to_elastic_query({ hrank: "family" }) ).to include(
        filters: [ { range: { "taxon.rank_level" => { gte: 0, lte: 30 } } } ])
    end

    it "filters by lrank and hrank" do
      expect( Observation.params_to_elastic_query({ lrank: "species", hrank: "family" }) ).to include(
        filters: [ { range: { "taxon.rank_level" => { gte: 10, lte: 30 } } } ])
    end

    it "filters by quality_grade" do
      expect( Observation.params_to_elastic_query({ quality_grade: "any" }) ).to include(
        filters: [  ] )
      expect( Observation.params_to_elastic_query({ quality_grade: "research" }) ).to include(
        filters: [ { terms: { quality_grade: [ "research" ] } } ] )
      expect( Observation.params_to_elastic_query({ quality_grade: "research,casual" }) ).to include(
        filters: [ { terms: { quality_grade: [ "research", "casual" ] } } ] )
    end

    it "filters by identifications" do
      expect( Observation.params_to_elastic_query({ identifications: "most_agree" }) ).to include(
        filters: [ { term: { identifications_most_agree: true } } ] )
      expect( Observation.params_to_elastic_query({ identifications: "some_agree" }) ).to include(
        filters: [ { term: { identifications_some_agree: true } } ] )
      expect( Observation.params_to_elastic_query({ identifications: "most_disagree" }) ).to include(
        filters: [ { term: { identifications_most_disagree: true } } ] )
    end

    it "filters by bounding box" do
      expect( Observation.params_to_elastic_query({ nelat: 1, nelng: 2, swlat: 3, swlng: 4 }) ).to include(
        filters: [ { envelope: { geojson: {
          nelat: 1, nelng: 2, swlat: 3, swlng: 4, user: nil } } } ])
    end

    it "filters by lat and lng" do
      expect( Observation.params_to_elastic_query({ lat: 10, lng: 15 }) ).to include(
        filters: [ { geo_distance: { distance: "10km", location: { lat: 10, lon: 15 } } } ] )
      expect( Observation.params_to_elastic_query({ lat: 10, lng: 15, radius: 2 }) ).to include(
        filters: [ { geo_distance: { distance: "2km", location: { lat: 10, lon: 15 } } } ] )
    end

    it "filters by reviewed" do
      u = User.make!
      # doesn't filter without a user
      expect( Observation.params_to_elastic_query({ reviewed: "true" }) ).to include( filters: [ ] )
      expect( Observation.params_to_elastic_query({ reviewed: "true" }, current_user: u) ).to include(
        filters: [ { term: { reviewed_by: u.id } } ] )
      expect( Observation.params_to_elastic_query({ reviewed: "false" }, current_user: u) ).to include(
        inverse_filters: [ { term: { reviewed_by: u.id } } ] )
    end

    it "filters by d1 d2 dates" do
      expect( Observation.params_to_elastic_query({ d1: "2015-03-25", d2: "2015-06-20" }) ).to include(
        filters: [ { range: { "observed_on_details.date": { gte: "2015-03-25", lte: "2015-06-20" }}}])
    end

    it "defaults d2 date to now" do
      expect( Observation.params_to_elastic_query({ d1: "2015-03-25" }) ).to include(
        filters: [ { range: { "observed_on_details.date": { gte: "2015-03-25", lte: Time.now.strftime("%F") }}}])
    end

    it "defaults d1 date to 1800" do
      expect( Observation.params_to_elastic_query({ d2: "2015-06-20" }) ).to include(
        filters: [ { range: { "observed_on_details.date": { gte: "1800-01-01", lte: "2015-06-20" }}}])
    end

    it "filters by d1 d2 datetimes" do
      time_filter = { time_observed_at: {
        gte: "2015-03-25T01:23:45+00:00",
        lte: "2015-04-25T03:33:33+00:00" } }
      date_filter = { "observed_on_details.date": {
        gte: "2015-03-25",
        lte: "2015-04-25" } }
      expect( Observation.params_to_elastic_query(
        { d1: "2015-03-25T01:23:45", d2: "2015-04-25T03:33:33" }) ).to include({
        filters: [{ bool: { should: [
          { bool: { must: [ { range: time_filter }, { exists: { field: "time_observed_at" } } ] } },
          { bool: {
            must: { range: date_filter },
            must_not: { exists: { field: "time_observed_at" } } } }
        ]}}]
      })
    end

    it "defaults d2 date to now" do
      time_filter = { time_observed_at: {
        gte: "2015-03-25T01:23:45+00:00",
        lte: Time.now.strftime("%FT%T%:z") } }
      date_filter = { "observed_on_details.date": {
        gte: "2015-03-25",
        lte: Time.now.strftime("%F") } }
      expect( Observation.params_to_elastic_query({ d1: "2015-03-25T01:23:45" }) ).to include({
        filters: [{ bool: { should: [
          { bool: { must: [ { range: time_filter }, { exists: { field: "time_observed_at" } } ] } },
          { bool: {
            must: { range: date_filter },
            must_not: { exists: { field: "time_observed_at" } } } }
        ]}}]
      })
    end

    it "defaults d1 date to 1800" do
      time_filter = { time_observed_at: {
        gte: "1800-01-01T00:00:00+00:00",
        lte: "2015-04-25T03:33:33+00:00" } }
      date_filter = { "observed_on_details.date": {
        gte: "1800-01-01",
        lte: "2015-04-25" } }
      expect( Observation.params_to_elastic_query({ d2: "2015-04-25T03:33:33" }) ).to include({
        filters: [{ bool: { should: [
          { bool: { must: [ { range: time_filter }, { exists: { field: "time_observed_at" } } ] } },
          { bool: {
            must: { range: date_filter },
            must_not: { exists: { field: "time_observed_at" } } } }
        ]}}]
      })
    end

    it "respects d1 d2 timezones" do
      time_filter = { time_observed_at: {
        gte: "2015-03-25T01:00:00+09:00",
        lte: "2015-04-25T23:00:00-08:00" } }
      date_filter = { "observed_on_details.date": {
        gte: "2015-03-25",
        lte: "2015-04-25" } }
      expect( Observation.params_to_elastic_query(
        { d1: "2015-03-25T01:00:00+09:00", d2: "2015-04-25T23:00:00-08:00" }) ).to include({
        filters: [{ bool: { should: [
          { bool: { must: [ { range: time_filter }, { exists: { field: "time_observed_at" } } ] } },
          { bool: {
            must: { range: date_filter },
            must_not: { exists: { field: "time_observed_at" } } } }
        ]}}]
      })
    end

    it "filters by h1 and h2" do
      expect( Observation.params_to_elastic_query({ h1: 8, h2: 10 }) ).to include(
        filters: [ { range: { "observed_on_details.hour" => { gte: 8, lte: 10 } } } ] )
      expect( Observation.params_to_elastic_query({ h1: 8, h2: 4 }) ).to include(
        filters: [ { bool: { should: [
          { range: { "observed_on_details.hour" => { gte: 8 } } },
          { range: { "observed_on_details.hour" => { lte: 4 } } } ] } } ] )
    end

    it "filters by m1 and m2" do
      expect( Observation.params_to_elastic_query({ m1: 8, m2: 10 }) ).to include(
        filters: [ { range: { "observed_on_details.month" => { gte: 8, lte: 10 } } } ] )
      expect( Observation.params_to_elastic_query({ m1: 8, m2: 4 }) ).to include(
        filters: [ { bool: { should: [
          { range: { "observed_on_details.month" => { gte: 8 } } },
          { range: { "observed_on_details.month" => { lte: 4 } } } ] } } ] )
    end

    it "filters by updated_since" do
      timeString = "2015-10-31T00:00:00+00:00"
      timeObject = Chronic.parse(timeString)
      expect( Observation.params_to_elastic_query({ updated_since: timeString }) ).to include(
        filters: [ { range: { updated_at: { gte: timeObject } } } ] )
    end

    it "filters by updated_since OR aggregation_user_ids" do
      timeString = "2015-10-31T00:00:00+00:00"
      timeObject = Chronic.parse(timeString)
      expect( Observation.params_to_elastic_query({
        updated_since: timeString, aggregation_user_ids: [ 1, 2 ] }) ).to include(
        filters: [ { bool: { should: [
          { range: { updated_at: { gte: timeObject } } },
          { terms: { "user.id" => [1, 2] } } ] } } ] )
    end

    it "filters by observation field values" do
      of = ObservationField.make!
      ofv_params = { whatever: { observation_field: of, value: "testvalue" } }
      expect( Observation.params_to_elastic_query({ ofv_params: ofv_params }) ).to include(
        filters: [ { nested: { path: "ofvs", query: { bool: { must: [
          { match: { "ofvs.name_ci" => of.name } },
          { match: { "ofvs.value_ci" => "testvalue" }}]}}}}])
    end

    it "filters by conservation status" do
      expect( Observation.params_to_elastic_query({ cs: "testing" }) ).to include(
        filters: [ { nested: { path: "taxon.statuses", query: { bool: {
          must: [ { terms: { "taxon.statuses.status" => [ "testing" ] } } ],
          must_not: [ { exists: { field: "taxon.statuses.place_id" }}]}}}}])
      expect( Observation.params_to_elastic_query({ cs: "testing", place_id: 6 })[:filters] ).to include(
        { nested: { path: "taxon.statuses", query: { bool: { must: [
          { terms: {"taxon.statuses.status" => [ "testing" ] } },
          { bool: { should: [
            { terms: { "taxon.statuses.place_id" => [ 6 ] } },
            { bool: { must_not: { exists: { field: "taxon.statuses.place_id" }}}}]}}]}}}})
    end

    it "filters by IUCN conservation status" do
      expect( Observation.params_to_elastic_query({ csi: "LC" }) ).to include(
        filters: [ { nested: { path: "taxon.statuses", query: { bool: {
          must: [ { terms: { "taxon.statuses.iucn" => [ 10 ] } } ],
          must_not: [ { exists: { field: "taxon.statuses.place_id" }}]}}}}])
      expect( Observation.params_to_elastic_query({ csi: "LC", place_id: 6 })[:filters] ).to include(
        { nested: { path: "taxon.statuses", query: { bool: { must: [
          { terms: {"taxon.statuses.iucn" => [ 10 ] } },
          { bool: { should: [
            { terms: { "taxon.statuses.place_id" => [ 6 ] } },
            { bool: { must_not: { exists: { field: "taxon.statuses.place_id" }}}}]}}]}}}})
    end

    it "filters by conservation status authority" do
      expect( Observation.params_to_elastic_query({ csa: "IUCN" }) ).to include(
        filters: [ { nested: { path: "taxon.statuses", query: { bool: {
          must: [ { terms: { "taxon.statuses.authority" => [ "iucn" ] } } ],
          must_not: [ { exists: { field: "taxon.statuses.place_id" }}]}}}}])
      expect( Observation.params_to_elastic_query({ csa: "IUCN", place_id: 6 })[:filters] ).to include(
        { nested: { path: "taxon.statuses", query: { bool: { must: [
          { terms: {"taxon.statuses.authority" => [ "iucn" ] } },
          { bool: { should: [
            { terms: { "taxon.statuses.place_id" => [ 6 ] } },
            { bool: { must_not: { exists: { field: "taxon.statuses.place_id" }}}}]}}]}}}})
    end

    it "filters by iconic_taxa" do
      animalia = Taxon.where(name: "Animalia").first
      expect( Observation.params_to_elastic_query({ iconic_taxa: [ animalia.name ] }) ).to include(
        filters: [ { terms: { "taxon.iconic_taxon_id" => [ animalia.id ] } } ])
        expect( Observation.params_to_elastic_query({ iconic_taxa: [ animalia.name, "unknown" ] }) ).to include(
          filters: [ { bool: { should: [
            { terms: { "taxon.iconic_taxon_id" => [ animalia.id ] } },
            { bool: { must_not: { exists: { field: "taxon.iconic_taxon_id" } } } } ] } } ])
    end

    it "filters by geoprivacy" do
      expect( Observation.params_to_elastic_query({ geoprivacy: "any" }) ).to include(
        filters: [ ])
      expect( Observation.params_to_elastic_query({ geoprivacy: "open" }) ).to include(
        inverse_filters: [ { exists: { field: :geoprivacy } } ])
      expect( Observation.params_to_elastic_query({ geoprivacy: "obscured" }) ).to include(
        filters: [ { term: { geoprivacy: "obscured" } } ])
      expect( Observation.params_to_elastic_query({ geoprivacy: "obscured_private" }) ).to include(
        filters: [ { terms: { geoprivacy: [ "obscured", "private" ] } } ])
    end

    it "filters by popular" do
      expect( Observation.params_to_elastic_query({ popular: "true" }) ).to include(
        filters: [ { range: { cached_votes_total: { gte: 1 } } } ])
      expect( Observation.params_to_elastic_query({ popular: "false" }) ).to include(
        filters: [ { term: { cached_votes_total: 0 } } ])
    end

    it "filters by min_id" do
      expect( Observation.params_to_elastic_query({ min_id: 99 }) ).to include(
        filters: [ { range: { id: { gte: 99 } } } ])
    end

  end
end
