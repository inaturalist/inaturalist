# frozen_string_literal: true

require "#{File.dirname( __FILE__ )}/../spec_helper"

describe ListedTaxaController, "create" do
  render_views
  let( :user ) { User.make! }
  let( :list ) { List.make!( user: user ) }
  elastic_models( Observation, Taxon, Place )
  before do
    sign_in( user )
  end

  it "should work" do
    taxon = Taxon.make!
    post :create, format: :json, params: {
      listed_taxon: { taxon_id: taxon.id, list_id: list.id }
    }
    expect( list.listed_taxa.where( taxon_id: taxon.id ) ).to be_exists
  end

  describe "establishment means propagation" do
    let( :parent ) { make_place_with_geom }
    let( :place ) { make_place_with_geom( parent: parent ) }
    let( :child ) { make_place_with_geom( parent: place ) }
    let( :taxon ) { Taxon.make! }
    let( :parent_listed_taxon ) { parent.check_list.add_taxon( taxon ) }
    let( :place_listed_taxon ) { place.check_list.add_taxon( taxon ) }
    let( :child_listed_taxon ) { child.check_list.add_taxon( taxon ) }
    it "should allow force_trickle_down_establishment_means for curators" do
      curator = make_curator
      sign_in( curator )
      child_listed_taxon.update( establishment_means: ListedTaxon::INTRODUCED )
      post :create, format: :json, params: { listed_taxon: {
        taxon_id: taxon.id,
        list_id: parent.check_list.id,
        establishment_means: ListedTaxon::NATIVE,
        force_trickle_down_establishment_means: true
      } }
      child_listed_taxon.reload
      expect( child_listed_taxon.establishment_means ).to eq ListedTaxon::NATIVE
    end
    it "should not allow force_trickle_down_establishment_means for non-curators" do
      child_listed_taxon.update( establishment_means: ListedTaxon::INTRODUCED )
      post :create, format: :json, params: { listed_taxon: {
        taxon_id: taxon.id,
        list_id: parent.check_list.id,
        establishment_means: ListedTaxon::NATIVE,
        force_trickle_down_establishment_means: true
      } }
      child_listed_taxon.reload
      expect( child_listed_taxon.establishment_means ).to eq ListedTaxon::INTRODUCED
    end
  end
end

describe ListedTaxaController, "update" do
  describe "establishment means propagation" do
    let( :parent ) { make_place_with_geom }
    let( :place ) { make_place_with_geom( parent: parent ) }
    let( :child ) { make_place_with_geom( parent: place ) }
    let( :taxon ) { Taxon.make! }
    let( :parent_listed_taxon ) { parent.check_list.add_taxon( taxon ) }
    let( :place_listed_taxon ) { place.check_list.add_taxon( taxon ) }
    let( :child_listed_taxon ) { child.check_list.add_taxon( taxon ) }
    it "should allow force_trickle_down_establishment_means for curators" do
      curator = make_curator
      sign_in( curator )
      child_listed_taxon.update( establishment_means: ListedTaxon::INTRODUCED )
      put :update, format: :json, params: { id: parent_listed_taxon.id, listed_taxon: {
        establishment_means: ListedTaxon::NATIVE,
        force_trickle_down_establishment_means: true
      } }
      child_listed_taxon.reload
      expect( child_listed_taxon.establishment_means ).to eq ListedTaxon::NATIVE
    end
    it "should not allow force_trickle_down_establishment_means for non-curators" do
      child_listed_taxon.update( establishment_means: ListedTaxon::INTRODUCED )
      put :update, format: :json, params: { id: parent_listed_taxon.id, listed_taxon: {
        establishment_means: ListedTaxon::NATIVE,
        force_trickle_down_establishment_means: true
      } }
      child_listed_taxon.reload
      expect( child_listed_taxon.establishment_means ).to eq ListedTaxon::INTRODUCED
    end
  end
end

describe ListedTaxaController, "destroy" do
  it "should destroy" do
    taxon = Taxon.make!
    place = make_place_with_geom
    check_list = List.find( place.check_list_id )
    @user = User.make!
    check_listed_taxon = check_list.add_taxon( taxon, user_id: @user.id )
    admin = make_admin
    sign_in( admin )
    delete :destroy, format: :json, params: { id: check_listed_taxon.id }
    expect( ListedTaxon.find_by_id( check_listed_taxon.id ) ).to be_blank
  end
  it "should log listed_taxon_alterations if listed_taxa has_atlas_or_complete_set? on destroy" do
    taxon = Taxon.make!
    atlas_place = make_place_with_geom( admin_level: 0 )
    atlas_place_check_list = List.find( atlas_place.check_list_id )
    @user = User.make!
    check_listed_taxon = atlas_place_check_list.add_taxon( taxon, user_id: @user.id )
    @other_user = make_admin
    Atlas.make!( user: @other_user, taxon: taxon, is_active: true )
    expect( check_listed_taxon.has_atlas_or_complete_set? ).to be true
    sign_in( @other_user )
    delete :destroy, format: :json, params: { id: check_listed_taxon.id }
    expect( ListedTaxon.find_by_id( check_listed_taxon.id ) ).to be_blank
    expect( ListedTaxonAlteration.where(
      taxon_id: taxon.id,
      user_id: @other_user.id,
      place_id: atlas_place.id,
      action: "unlisted"
    ).first ).not_to be_blank
  end
end
