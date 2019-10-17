require "spec_helper"

describe Observation do
  describe "site_search_params" do
    it "filters by site unless specified" do
      s = Site.make!(preferred_site_observations_filter: Site::OBSERVATIONS_FILTERS_SITE)
      req_params = { }
      query_params = Observation.site_search_params(s, req_params)
      expect( query_params[:site_id] ).to eq s.id
      req_params = { site_id: s.id + 1 }
      query_params = Observation.site_search_params(s, req_params)
      expect( query_params[:site_id] ).to eq (s.id + 1)
    end

    it "filters by site place unless specified" do
      s = Site.make!(preferred_site_observations_filter: Site::OBSERVATIONS_FILTERS_PLACE,
        place: make_place_with_geom)
      req_params = { }
      query_params = Observation.site_search_params(s, req_params)
      expect( query_params[:place_id] ).to eq s.place.id
      req_params = { place_id: s.place.id + 1 }
      query_params = Observation.site_search_params(s, req_params)
      expect( query_params[:place_id] ).to eq (s.place.id + 1)
    end

    it "filters by site boundary unless specified" do
      s = Site.make!(preferred_site_observations_filter: Site::OBSERVATIONS_FILTERS_BOUNDING_BOX,
        preferred_geo_swlat: 0,
        preferred_geo_swlng: 0,
        preferred_geo_nelat: 1,
        preferred_geo_nelng: 1)
      req_params = { }
      query_params = Observation.site_search_params(s, req_params)
      expect( query_params[:swlat] ).to eq "0"
      expect( query_params[:swlng] ).to eq "0"
      expect( query_params[:nelat] ).to eq "1"
      expect( query_params[:nelng] ).to eq "1"
      req_params = { nelat: 99 }
      query_params = Observation.site_search_params(s, req_params)
      expect( query_params[:swlat] ).to be nil
      expect( query_params[:swlng] ).to be nil
      expect( query_params[:nelat] ).to eq 99
      expect( query_params[:nelng] ).to be nil
    end

    it "doesn't add site filters to project queries" do
      s = Site.make!(preferred_site_observations_filter: Site::OBSERVATIONS_FILTERS_SITE)
      req_params = { projects: [ Project.make!.id ] }
      query_params = Observation.site_search_params(s, req_params)
      expect( query_params[:site_id] ).to be nil
    end
  end

  describe "get_search_params" do
    it "applies site-specific options" do
      s = Site.make!(preferred_site_observations_filter: Site::OBSERVATIONS_FILTERS_SITE)
      req_params = { }
      query_params = Observation.get_search_params(req_params, { site: s })
      expect( query_params[:site_id] ).to eq s.id
    end

    it "doesn't apply site-specific options for certain queries" do
      s = Site.make!(preferred_site_observations_filter: Site::OBSERVATIONS_FILTERS_SITE)
      req_params = { projects: [ Project.make!.id ] }
      query_params = Observation.get_search_params(req_params, { site: s })
      expect( query_params[:site_id] ).to be nil
    end
  end

  describe "elastic_taxon_leaf_ids" do
    elastic_models( Observation )
    before(:each) do
      Taxon.destroy_all
      @family = Taxon.make!(name: "Hominidae", rank: "family")
      @genus = Taxon.make!(name: "Homo", rank: "genus", parent: @family)
      @sapiens = Taxon.make!(name: "Homo sapiens", rank: "species", parent: @genus)
      @habilis = Taxon.make!(name: "Homo habilis", rank: "species", parent: @genus)
      AncestryDenormalizer.truncate
      AncestryDenormalizer.denormalize
    end

    it "returns the leaf taxon id" do
      2.times{ Observation.make!(taxon: @family) }
      expect( Observation.elastic_taxon_leaf_ids.size ).to eq 1
      expect( Observation.elastic_taxon_leaf_ids[0] ).to eq @family.id
      2.times{ Observation.make!(taxon: @genus) }
      expect( Observation.elastic_taxon_leaf_ids.size ).to eq 1
      expect( Observation.elastic_taxon_leaf_ids[0] ).to eq @genus.id
      2.times{ Observation.make!(taxon: @sapiens) }
      expect( Observation.elastic_taxon_leaf_ids.size ).to eq 1
      expect( Observation.elastic_taxon_leaf_ids[0] ).to eq @sapiens.id
      2.times{ Observation.make!(taxon: @habilis) }
      expect( Observation.elastic_taxon_leaf_ids.size ).to eq 2
      expect( Observation.elastic_taxon_leaf_ids[0] ).to eq @sapiens.id
      expect( Observation.elastic_taxon_leaf_ids[1] ).to eq @habilis.id
    end
  end
end
