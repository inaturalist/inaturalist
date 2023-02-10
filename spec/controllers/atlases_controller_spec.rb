# frozen_string_literal: true

require "#{File.dirname( __FILE__ )}/../spec_helper"

describe AtlasesController do
  describe "alter_atlas_presence" do
    let( :user ) { make_curator }
    let( :genus ) { Taxon.make!( rank: Taxon::GENUS ) }
    let( :taxon ) { Taxon.make!( rank: Taxon::SPECIES, parent: genus ) }
    let( :place ) { make_place_with_geom( admin_level: Place::STATE_LEVEL ) }
    let( :atlas ) { Atlas.make!( taxon: taxon, user: user ) }
    it "should create a listing if one doesn't exist" do
      sign_in user
      post :alter_atlas_presence, params: { id: atlas.id, taxon_id: taxon.id, place_id: place.id }
      lt = ListedTaxon.where( taxon_id: taxon.id, place_id: place.id, list_id: place.check_list_id ).first
      expect( lt ).not_to be_blank
    end

    it "should destroy a listing if one does exist" do
      expect( taxon ).not_to be_blank
      check_list = List.find( place.check_list_id )
      check_list.add_taxon( taxon )
      sign_in user
      post :alter_atlas_presence, params: { id: atlas.id, taxon_id: taxon.id, place_id: place.id }
      lt = ListedTaxon.where( taxon_id: taxon.id, place_id: place.id, list_id: place.check_list_id ).first
      expect( lt ).to be_blank
    end

    it "should create a listing if there's a comprehensive list that isn't the place's default list" do
      comprehensive_list = place.check_lists.create!( taxon: genus, user: user, comprehensive: true )
      sign_in user
      post :alter_atlas_presence, format: :json, params: { id: atlas.id, taxon_id: taxon.id, place_id: place.id }
      lt = ListedTaxon.where( taxon_id: taxon.id, place_id: place.id, list_id: comprehensive_list.id ).first
      expect( lt ).not_to be_blank
    end

    it "should create a listing on the default list if there's a comprehensive list" do
      place.check_lists.create!( taxon: genus, user: user, comprehensive: true )
      sign_in user
      post :alter_atlas_presence, format: :json, params: { id: atlas.id, taxon_id: taxon.id, place_id: place.id }
      lt = ListedTaxon.where( taxon_id: taxon.id, place_id: place.id, list_id: place.check_list_id ).first
      expect( lt ).not_to be_blank
    end

    it "should destroy a listing from a comprehensive list when destroying a default listing" do
      comprehensive_list = place.check_lists.create!( taxon: genus, user: user, comprehensive: true )
      comprehensive_list.add_taxon( taxon )
      comprehensive_list.place.check_list.add_taxon( taxon )
      sign_in user
      post :alter_atlas_presence, format: :json, params: { id: atlas.id, taxon_id: taxon.id, place_id: place.id }
      lt = ListedTaxon.where( taxon_id: taxon.id, place_id: place.id, list_id: comprehensive_list.id ).first
      expect( lt ).to be_blank
    end

    it "should create a listing if there's a comprehensive list for the place's parent" do
      parent_place = make_place_with_geom( admin_level: 0 )
      place.update( parent: parent_place )
      parent_place.check_lists.create!( taxon: genus, user: user, comprehensive: true )
      sign_in user
      post :alter_atlas_presence, format: :json, params: { id: atlas.id, taxon_id: taxon.id, place_id: place.id }
      lt = ListedTaxon.where( taxon_id: taxon.id, place_id: place.id, list_id: place.check_list.id ).first
      expect( lt ).not_to be_blank
    end
  end
end
