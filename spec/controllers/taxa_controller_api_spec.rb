# frozen_string_literal: true

require "#{File.dirname( __FILE__ )}/../spec_helper"

shared_examples_for "a TaxaController without authentication" do
  describe "index" do
    elastic_models( Observation )
    it "should filter by place_id" do
      t = Taxon.make!
      p = make_place_with_geom
      without_delay do
        p.check_list.add_taxon( t )
      end
      get :index, format: :json, params: { place_id: p.id }
      expect( response.headers["X-Total-Entries"].to_i ).to eq( 1 )
    end

    it "should show iconic taxa if no search params" do
      Taxon.make!( is_iconic: true )
      Taxon.make!
      get :index, format: :json
      json = JSON.parse( response.body )
      json.each do | json_taxon |
        expect( json_taxon["is_iconic"] ).to be true
      end
    end

    it "should filter by names" do
      t1 = Taxon.make!
      t2 = Taxon.make!
      t3 = Taxon.make!
      taxa = [t1, t2, t3]
      get :index, format: :json, params: { names: taxa.map( &:name ).join( "," ) }
      json = JSON.parse( response.body )
      expect( json.size ).to eq 3
      taxa.each do | t |
        expect( json.detect {| jt | jt["id"] == t.id } ).not_to be_blank
      end
    end
  end

  describe "search" do
    elastic_models( Observation, Taxon, Place )

    it "should filter by place_id" do
      taxon_not_in_place = Taxon.make!
      taxon_in_place = Taxon.make!
      p = make_place_with_geom
      without_delay do
        p.check_list.add_taxon( taxon_in_place )
      end
      get :search, format: :json, params: { places: p.id.to_s }
      json = JSON.parse( response.body )
      expect( json.detect {| t | t["id"] == taxon_not_in_place.id } ).to be_blank
      expect( json.detect {| t | t["id"] == taxon_in_place.id } ).not_to be_blank
    end

    it "returns results in the configured place" do
      taxon_not_in_place = Taxon.make!( name: "Disco stu" )
      taxon_in_place = Taxon.make!( name: "Disco stu" )
      p = make_place_with_geom
      without_delay do
        p.check_list.add_taxon( taxon_in_place )
      end
      Site.default.update( place_id: p.id )
      get :search, format: :json, params: { q: "disco" }
      json = JSON.parse( response.body )
      expect( json.detect {| t | t["id"] == taxon_not_in_place.id } ).to be_blank
      expect( json.detect {| t | t["id"] == taxon_in_place.id } ).not_to be_blank
    end

    it "returns all results when there are none in the configured place" do
      taxon_not_in_place = Taxon.make!( name: "nonsense" )
      taxon2_not_in_place = Taxon.make!( name: "nonsense" )
      p = make_place_with_geom
      Site.default.update( place_id: p.id )
      get :search, format: :json, params: { q: "nonsense" }
      json = JSON.parse( response.body )
      expect( json.detect {| t | t["id"] == taxon_not_in_place.id } ).not_to be_blank
      expect( json.detect {| t | t["id"] == taxon2_not_in_place.id } ).not_to be_blank
    end

    it "filters by is_active=true" do
      active = Taxon.make!( is_active: true )
      Taxon.make!( is_active: false )
      get :search, format: :json, params: { is_active: "true" }
      json = JSON.parse( response.body )
      expect( json.length ).to eq 1
      expect( json.first["id"] ).to eq active.id
    end

    it "filters by is_active=false" do
      Taxon.make!( is_active: true )
      inactive = Taxon.make!( is_active: false )
      get :search, format: :json, params: { is_active: "false" }
      json = JSON.parse( response.body )
      expect( json.length ).to eq 1
      expect( json.first["id"] ).to eq inactive.id
    end

    it "returns all taxa when is_active=any" do
      Taxon.make!( is_active: true )
      Taxon.make!( is_active: false )
      get :search, format: :json, params: { is_active: "any" }
      json = JSON.parse( response.body )
      expect( json.length ).to eq 2
    end

    it "should place an exact match first" do
      [
        ["Octopus rubescens", "Eastern Pacific Red Octopus octopus octopus octopus"],
        ["Octopus bimaculatus", "Two-spot Octopus"],
        ["Octopus cyanea", "Day Octopus"],
        ["Schefflera actinophylla", "octopus there"],
        ["Octopus vulgaris", "Day Octopus"],
        ["Enteroctopus dofleini", "Giant Pacific Octopus"]
      ].each do | sciname, comname |
        t = Taxon.make!( name: sciname, rank: "species" )
        TaxonName.make!( taxon: t, name: comname )
      end
      t = Taxon.make!( name: "Octopus", rank: "genus" )
      get :search, format: :json, params: { q: "octopus" }
      names = JSON.parse( response.body ).map {| jt | jt["name"] }
      expect( names.first ).to eq t.name
    end

    it "should not return exact results of inactive taxa" do
      t = Taxon.make!( name: "Octopus", rank: "genus", is_active: true )
      get :search, format: :json, params: { q: "octopus" }
      expect( JSON.parse( response.body ).first["name"] ).to eq t.name
      t.update_attribute( :is_active, false )
      get :search, format: :json, params: { q: "octopus" }
      expect( JSON.parse( response.body ) ).to be_empty
    end

    # unfortunately i don't really know how to test this b/c it's not clear
    # how elasticsearch sorts its results
    it "should place an exact match first even if it's not on the first page of results"
  end

  describe "autocomplete" do
    elastic_models( Observation, Taxon, Place )

    it "filters by is_active=true" do
      active = Taxon.make!( name: "test", is_active: true )
      Taxon.make!( name: "test", is_active: false )
      get :autocomplete, format: :json, params: { q: "test", is_active: "true" }
      json = JSON.parse( response.body )
      expect( json.length ).to eq 1
      expect( json.first["id"] ).to eq active.id
    end

    it "filters by is_active=false" do
      Taxon.make!( name: "test", is_active: true )
      inactive = Taxon.make!( name: "test", is_active: false )
      get :autocomplete, format: :json, params: { q: "test", is_active: "false" }
      json = JSON.parse( response.body )
      expect( json.length ).to eq 1
      expect( json.first["id"] ).to eq inactive.id
    end

    it "returns all taxa when is_active=any" do
      Taxon.make!( name: "test", is_active: true )
      Taxon.make!( name: "test", is_active: false )
      get :autocomplete, format: :json, params: { q: "test", is_active: "any" }
      json = JSON.parse( response.body )
      expect( json.length ).to eq 2
    end
  end

  describe "show" do
    elastic_models( Observation )
    it "should include range kml url" do
      tr = TaxonRange.make!( url: "http://foo.bar/range.kml" )
      get :show, format: :json, params: { id: tr.taxon_id }
      response_taxon = JSON.parse( response.body )
      expect( response_taxon["taxon_range_kml_url"] ).to eq tr.kml_url
    end

    describe "with default photo" do
      let( :photo ) do
        LocalPhoto.make!(
          "id" => 1576,
          "license" => 4,
          "native_page_url" => "http://localhost:3000/photos/1576",
          "native_photo_id" => "1576",
          "native_username" => "kueda"
        )
      end
      let( :taxon_photo ) { TaxonPhoto.make!( photo: photo ) }
      let( :taxon ) { taxon_photo.taxon }

      it "should include all image url sizes" do
        get :show, format: :json, params: { id: taxon.id }
        response_taxon = JSON.parse( response.body )
        %w(thumb small medium large).each do | size |
          expect( response_taxon["default_photo"]["#{size}_url"] ).to eq photo.send( "#{size}_url" )
        end
      end

      it "should include license url" do
        get :show, format: :json, params: { id: taxon.id }
        response_taxon = JSON.parse( response.body )
        expect( response_taxon["default_photo"]["license_url"] ).to eq photo.license_url
      end
    end
  end

  describe "children" do
    it "should only show active taxa by default" do
      p = Taxon.make!( rank: Taxon::GENUS )
      active = Taxon.make!( parent: p, rank: Taxon::SPECIES )
      inactive = Taxon.make!( parent: p, is_active: false, rank: Taxon::SPECIES )
      get :children, format: :json, params: { id: p.id }
      taxa = JSON.parse( response.body )
      expect( taxa.detect {| t | t["id"] == active.id } ).not_to be_blank
      expect( taxa.detect {| t | t["id"] == inactive.id } ).to be_blank
    end
    it "should show all taxa if requested" do
      p = Taxon.make!( rank: Taxon::GENUS )
      active = Taxon.make!( parent: p, rank: Taxon::SPECIES )
      inactive = Taxon.make!( parent: p, is_active: false, rank: Taxon::SPECIES )
      get :children, format: :json, params: { id: p.id, is_active: "any" }
      taxa = JSON.parse( response.body )
      expect( taxa.detect {| t | t["id"] == active.id } ).not_to be_blank
      expect( taxa.detect {| t | t["id"] == inactive.id } ).not_to be_blank
    end
  end
end

shared_examples_for "a TaxaController with authentication" do
  describe "show" do
    it "should return names specific to the user's place" do
      t = Taxon.make!( rank: Taxon::SPECIES )
      TaxonName.make!( taxon: t, lexicon: TaxonName::ENGLISH )
      tn_place = TaxonName.make!( taxon: t, lexicon: TaxonName::ENGLISH )
      ptn = PlaceTaxonName.make!( taxon_name: tn_place )
      user.update( place_id: ptn.place_id )
      get :show, format: :json, params: { id: t.id }
      json = JSON.parse( response.body )
      expect( json["common_name"]["name"] ).to eq tn_place.name
    end
  end
end

describe TaxaController do
  it_behaves_like "a TaxaController without authentication"
end

describe TaxaController, "with authentication" do
  let( :user ) { User.make! }
  before { sign_in( user ) }
  it_behaves_like "a TaxaController with authentication"
end
