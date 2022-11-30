require "spec_helper"

describe "Observation Index" do
  before( :all ) do
    @starting_time_zone = Time.zone
    Time.zone = ActiveSupport::TimeZone["Samoa"]
    load_test_taxa
  end
  after( :all ) { Time.zone = @starting_time_zone }
  elastic_models( Observation, Taxon )

  it "as_indexed_json should return a hash" do
    o = Observation.make!
    json = o.as_indexed_json
    expect( json ).to be_a Hash
  end

  it "sets location based on private coordinates if exist" do
    o = Observation.make!(latitude: 3.0, longitude: 4.0)
    o.update(private_latitude: 1.0, private_longitude: 2.0)
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
    cs.update(place: present_place)
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

  it "indexes identifier_user_ids" do
    o = Observation.make!
    Identification.where(observation_id: o.id).destroy_all
    5.times{ Identification.make!(observation: o) }
    json = o.as_indexed_json
    expect( json[:identifier_user_ids].length ).to eq 5
  end

  it "indexes owners_identification_from_vision" do
    o = Observation.make!( taxon: Taxon.make!, owners_identification_from_vision: true )
    expect( o.owners_identification_from_vision ).to be true
    json = o.as_indexed_json
    expect( json[:owners_identification_from_vision] ).to be true
  end

  it "indexes applications based on user agent" do
    OauthApplication.make!(name: "iNaturalist Android App")
    OauthApplication.make!(name: "iNaturalist iPhone App")
    o = Observation.make!( oauth_application_id: 11 )
    expect( o.as_indexed_json[:oauth_application_id] ).to eq 11
    o.update( oauth_application_id: nil,
      user_agent: "iNaturalist/1.5.1 (Build 195; Android 3.18..." )
    expect( o.as_indexed_json[:oauth_application_id] ).to eq OauthApplication.inaturalist_android_app.id
    o.update( user_agent: "iNaturalist/2.7 (iOS iOS 10.3.2 iPhone)" )
    expect( o.as_indexed_json[:oauth_application_id] ).to eq OauthApplication.inaturalist_iphone_app.id
  end

  it "private_place_ids should include places that contain the positional_accuracy" do
    place = make_place_with_geom
    o = Observation.make!( latitude: place.latitude, longitude: place.longitude, positional_accuracy: 10 )
    expect( o.as_indexed_json[:private_place_ids] ).to include place.id
  end
  it "private_place_ids should not include places that do not contain the positional_accuracy" do
    place = make_place_with_geom( wkt: "MULTIPOLYGON(((0 0,0 0.1,0.1 0.1,0.1 0,0 0)))" )
    o = Observation.make!( latitude: place.latitude, longitude: place.longitude, positional_accuracy: 99999 )
    expect( o.as_indexed_json[:private_place_ids] ).not_to include place.id
  end
  it "private_place_ids should include places that do not contain the positional_accuracy but are county-level" do
    place = make_place_with_geom(
      wkt: "MULTIPOLYGON(((0 0,0 0.1,0.1 0.1,0.1 0,0 0)))",
      place_type: Place::COUNTY,
      admin_level: Place::COUNTY_LEVEL
    )
    o = Observation.make!(
      latitude: place.latitude,
      longitude: place.longitude,
      positional_accuracy: 99999
    )
    expect( o.as_indexed_json[:private_place_ids] ).to include place.id
  end

  it "should not count needs_id votes toward faves_count" do
    o = Observation.make!
    o.vote_by voter: User.make!, vote: true, vote_scope: "needs_id"
    expect( o.cached_votes_total ).to eq 1
    expect( o.faves_count ).to eq 0
    o.reload
    o.vote_by voter: User.make!, vote: true
    expect( o.cached_votes_total ).to eq 2
    expect( o.faves_count ).to eq 1
  end

  describe "photos_count" do
    it "should not count photos with copyright infringement flags" do
      o = Observation.make!
      3.times { make_observation_photo( observation: o ) }
      Flag.make!( flag: Flag::COPYRIGHT_INFRINGEMENT, flaggable: o.photos.last )
      o.reload
      expect( o.photos.length ).to eq 3
      expect( o.as_indexed_json[:photos_count] ).to eq 2
    end
    it "should count photos with resolved copyright infringement flags" do
      o = Observation.make!
      3.times { make_observation_photo( observation: o ) }
      f = Flag.make!( flag: Flag::COPYRIGHT_INFRINGEMENT, flaggable: o.photos.last )
      o.reload
      expect( o.photos.length ).to eq 3
      expect( o.as_indexed_json[:photos_count] ).to eq 2
      allow( f.flaggable ).to receive(:flagged_with).and_return( true )
      f.update( resolved: true )
      expect( f ).to be_resolved
      o.reload
      expect( o.as_indexed_json[:photos_count] ).to eq 3
    end
  end

  describe "place_ids" do
    it "should include places that contain the uncertainty cell" do
      place = make_place_with_geom
      o = Observation.make!( latitude: place.latitude, longitude: place.longitude, geoprivacy: Observation::OBSCURED )
      expect( o.as_indexed_json[:place_ids] ).to include place.id
    end
    it "should not include places that do not contain the uncertainty cell" do
      place = make_place_with_geom
      o = Observation.make!( latitude: place.bounding_box[2], longitude: place.bounding_box[3] )
      expect( o.as_indexed_json[:place_ids] ).not_to include place.id
    end
    it "should include county-level places that do not contain the uncertainty cell" do
      place = make_place_with_geom(
        place_type: Place::COUNTY,
        admin_level: Place::COUNTY_LEVEL
      )
      o = Observation.make!( latitude: place.bounding_box[2], longitude: place.bounding_box[3] )
      expect( o.as_indexed_json[:place_ids] ).to include place.id
    end
  end

  describe "params_to_elastic_query" do
    it "filters by project rules" do
      project = Project.make!
      rule = ProjectObservationRule.make!(operator: "identified?", ruler: project)
      expect( Observation.params_to_elastic_query(apply_project_rules_for: project.id)).
        to include( filters: [{ exists: { field: "taxon" } }])
    end

    it "filters by list taxa" do
      list = List.make!
      lt1 = ListedTaxon.make!( list: list, taxon: Taxon.make! )
      lt2 = ListedTaxon.make!( list: list, taxon: Taxon.make! )
      filtered_ancestor_ids = Observation.params_to_elastic_query(
        list_id: list.id
      )[:filters][0][:terms]["taxon.ancestor_ids.keyword"]
      expect( filtered_ancestor_ids ).to include lt1.taxon_id
      expect( filtered_ancestor_ids ).to include lt2.taxon_id
    end

    it "doesn't apply a site filter unless the site wants one" do
      s = Site.make!(preferred_site_observations_filter: nil)
      expect( Observation.params_to_elastic_query({ }, site: s) ).to include( filters: [ ] )
    end

    it "looks up taxa by ids before querying observations" do
      taxon = Taxon.make!( name: "testname" )
      eq = Observation.params_to_elastic_query({ q: "testname", search_on: "names" })
      expect( eq[:filters] ).to eq( [{ terms: { "taxon.id" => [taxon.id] } }])
    end

    it "adds an impossible filter when taxa searches return no results" do
      eq = Observation.params_to_elastic_query({ q: "s", search_on: "names" })
      expect( eq[:filters] ).to eq( [{ term: { id: -1 } }])
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

    it "queries all fields by default when there are no matching taxa" do
      eq = Observation.params_to_elastic_query({ q: "s" })
      multi_match = eq[:filters][0][:multi_match]
      expect( multi_match[:query] ).to eq( "s" )
      expect( multi_match[:operator] ).to eq( "and" )
      expect( multi_match[:fields] ).to include( :tags )
      expect( multi_match[:fields] ).to include( :description )
      expect( multi_match[:fields] ).to include( :place_guess )
    end

    it "queries core observation attributes or matching taxa" do
      taxon = Taxon.make!( name: "testname" )
      eq = Observation.params_to_elastic_query({ q: "testname" })
      expect( eq[:filters][0] ).to eq( {
        bool: {
          should: [{
            multi_match: {
              query: "testname",
              operator: "and",
              fields: [:tags, :description, :place_guess]
            }
          },
          {
            terms: {
              "taxon.id" => [taxon.id]
            }
          }]
        }
      } )
    end

    it "filters by param values" do
      [ { http_param: :rank, es_field: "taxon.rank" },
        { http_param: :observed_on_day, es_field: "observed_on_details.day" },
        { http_param: :observed_on_month, es_field: "observed_on_details.month" },
        { http_param: :observed_on_year, es_field: "observed_on_details.year" },
        { http_param: :place_id, es_field: "place_ids.keyword" },
        { http_param: :site_id, es_field: "site_id.keyword" }
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
      [ { http_param: :with_photos, es_field: "photos_count" },
        { http_param: :with_sounds, es_field: "sounds_count" },
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
      filters: [ { terms: { "site_id.keyword" => [ s.id ] } } ] )
    end

    it "filters by site place" do
      s = Site.make!(preferred_site_observations_filter: Site::OBSERVATIONS_FILTERS_PLACE, place: make_place_with_geom)
      expect( Observation.params_to_elastic_query({ }, site: s) ).to include(
        filters: [ { terms: { "place_ids.keyword" => [ s.place.id ] } } ] )
    end

    it "filters by site bounding box" do
      s = Site.make!(preferred_site_observations_filter: Site::OBSERVATIONS_FILTERS_BOUNDING_BOX,
        preferred_geo_nelat: 55, preferred_geo_nelng: 66, preferred_geo_swlat: 77, preferred_geo_swlng: 88)
      expect( Observation.params_to_elastic_query({ }, site: s) ).to include(
        filters: [{ envelope: { geojson: { nelat: "55", nelng: "66", swlat: "77", swlng: "88", user: nil } } }] )
    end

    it "filters by user and user_id" do
      user = create :user
      expect( Observation.params_to_elastic_query({ user: user.id }) ).to include(
        filters: [ { term: { "user.id.keyword" => user.id } } ] )
      expect( Observation.params_to_elastic_query({ user_id: user.id }) ).to include(
        filters: [ { term: { "user.id.keyword" => user.id } } ] )
    end

    it "filters by taxon_id" do
      expect( Observation.params_to_elastic_query({ observations_taxon: 1 }) ).to include(
        filters: [ { term: { "taxon.ancestor_ids.keyword" => 1 } } ] )
    end

    it "filters by taxon_ids" do
      expect( Observation.params_to_elastic_query({ observations_taxon_ids: [ 1, 2 ] }) ).to include(
        filters: [ { terms: { "taxon.ancestor_ids.keyword" => [ 1, 2 ] } } ] )
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
        filters: [ { exists: { field: "photo_licenses" } } ] )
      expect( Observation.params_to_elastic_query({ photo_license: "none" }) ).to include(
        inverse_filters: [ { exists: { field: "photo_licenses" } } ] )
      expect( Observation.params_to_elastic_query({ photo_license: "CC-BY" }) ).to include(
        filters: [ { terms: { "photo_licenses" => [ "cc-by" ] } } ] )
      expect( Observation.params_to_elastic_query({ photo_license: [ "CC-BY", "CC-BY-NC" ] }) ).to include(
        filters: [ { terms: { "photo_licenses" => [ "cc-by", "cc-by-nc" ] } } ] )
    end

    it "filters by sound license" do
      expect( Observation.params_to_elastic_query({ sound_license: "any" }) ).to include(
        filters: [ { exists: { field: "sound_licenses" } } ] )
      expect( Observation.params_to_elastic_query({ sound_license: "none" }) ).to include(
        inverse_filters: [ { exists: { field: "sound_licenses" } } ] )
      expect( Observation.params_to_elastic_query({ sound_license: "CC-BY" }) ).to include(
        filters: [ { terms: { "sound_licenses" => [ "cc-by" ] } } ] )
      expect( Observation.params_to_elastic_query({ sound_license: [ "CC-BY", "CC-BY-NC" ] }) ).to include(
        filters: [ { terms: { "sound_licenses" => [ "cc-by", "cc-by-nc" ] } } ] )
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
        inverse_filters: [ { term: { "project_ids.keyword": p.id } } ] )
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
          { terms: { "user.id.keyword" => [1, 2] } } ] } } ] )
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

  describe "prepare_batch_for_index" do
    let( :country ) do
      make_place_with_geom(
        admin_level: Place::COUNTRY_LEVEL,
        wkt: "MULTIPOLYGON(((0 0,0 1,1 1,1 0,0 0)))"
      )
    end
    let( :state ) do
      make_place_with_geom(
        admin_level: Place::STATE_LEVEL, parent: country,
        wkt: "MULTIPOLYGON(((0.1 0.1,0.1 0.9,0.9 0.9,0.9 0.1,0.1 0.1)))"
      )
    end
    let( :county ) do
      make_place_with_geom(
        admin_level: Place::STATE_LEVEL, parent: state,
        wkt: "MULTIPOLYGON(((0.2 0.2,0.2 0.8,0.8 0.8,0.8 0.2,0.2 0.2)))"
      )
    end
    it "should include country-, state-, and county-level public and private place IDs by default" do
      o = Observation.make!(
        latitude: county.latitude,
        longitude: county.longitude,
        positional_accuracy: 99999
      )
      Observation.prepare_batch_for_index( [o] )
      [country, state, county].each do |p|
        expect( o.indexed_place_ids ).to include p.id
        expect( o.indexed_private_place_ids ).to include p.id
      end
    end
    it "should not include country-, state-, and county-level public place IDs when taxon geoprivacy is private" do
      cs = ConservationStatus.make!( geoprivacy: Observation::PRIVATE )
      o = Observation.make!(
        taxon: cs.taxon,
        latitude: county.latitude,
        longitude: county.longitude,
        positional_accuracy: 99999
      )
      Observation.prepare_batch_for_index( [o] )
      [country, state, county].each do |p|
        expect( o.indexed_place_ids ).not_to include p.id
        expect( o.indexed_private_place_ids ).to include p.id
      end
    end
    it "should have no place IDs when geoprivacy is private" do
      p = make_place_with_geom
      o = make_research_grade_candidate_observation(
        geoprivacy: Observation::PRIVATE,
        latitude: p.latitude,
        longitude: p.longitude
      )
      Observation.prepare_batch_for_index( [o] )
      expect( o.indexed_place_ids ).to be_blank
    end
    it "should have no place IDs when the taxon has a conservation status with private geoprivacy" do
      p = make_place_with_geom
      cs = ConservationStatus.make!( geoprivacy: Observation::PRIVATE )
      o = make_research_grade_candidate_observation(
        taxon: cs.taxon,
        latitude: p.latitude,
        longitude: p.longitude
      )
      Observation.prepare_batch_for_index( [o] )
      expect( o.indexed_place_ids ).to be_blank
    end
  end
end
