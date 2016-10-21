require File.dirname(__FILE__) + '/../spec_helper'

describe ListedTaxaController, "create" do
  render_views
  let(:user) { User.make! }
  let(:list) { List.make!(:user => user) }
  before(:each) { enable_elastic_indexing([ Observation, Taxon, Place ]) }
  after(:each) { disable_elastic_indexing([ Observation, Taxon, Place ]) }
  before do
    http_login(user)
  end

  it "should work" do
    taxon = Taxon.make!
    post :create, :format => :json, :listed_taxon => {:taxon_id => taxon.id, :list_id => list.id}
    expect(list.listed_taxa.where(:taxon_id => taxon.id)).to be_exists
  end

  describe "establishment means propagation" do
    let(:parent) { Place.make! }
    let(:place) { Place.make!(:parent => parent) }
    let(:child) { Place.make!(:parent => place) }
    let(:taxon) { Taxon.make! }
    let(:parent_listed_taxon) { parent.check_list.add_taxon(taxon) }
    let(:place_listed_taxon) { place.check_list.add_taxon(taxon) }
    let(:child_listed_taxon) { child.check_list.add_taxon(taxon) }
    it "should allow force_trickle_down_establishment_means for curators" do
      curator = make_curator
      http_login(curator)
      child_listed_taxon.update_attributes(:establishment_means => ListedTaxon::INTRODUCED)
      post :create, :format => :json, :listed_taxon => {
        :taxon_id => taxon.id, 
        :list_id => parent.check_list.id,
        :establishment_means => ListedTaxon::NATIVE,
        :force_trickle_down_establishment_means => true
      }
      child_listed_taxon.reload
      expect(child_listed_taxon.establishment_means).to eq ListedTaxon::NATIVE
    end
    it "should not allow force_trickle_down_establishment_means for non-curators" do
      child_listed_taxon.update_attributes(:establishment_means => ListedTaxon::INTRODUCED)
      post :create, :format => :json, :listed_taxon => {
        :taxon_id => taxon.id, 
        :list_id => parent.check_list.id,
        :establishment_means => ListedTaxon::NATIVE,
        :force_trickle_down_establishment_means => true
      }
      child_listed_taxon.reload
      expect(child_listed_taxon.establishment_means).to eq ListedTaxon::INTRODUCED
    end
  end
end

describe ListedTaxaController, "update" do
  describe "establishment means propagation" do
    let(:parent) { Place.make! }
    let(:place) { Place.make!(:parent => parent) }
    let(:child) { Place.make!(:parent => place) }
    let(:taxon) { Taxon.make! }
    let(:parent_listed_taxon) { parent.check_list.add_taxon(taxon) }
    let(:place_listed_taxon) { place.check_list.add_taxon(taxon) }
    let(:child_listed_taxon) { child.check_list.add_taxon(taxon) }
    it "should allow force_trickle_down_establishment_means for curators" do
      curator = make_curator
      http_login(curator)
      child_listed_taxon.update_attributes(:establishment_means => ListedTaxon::INTRODUCED)
      put :update, :format => :json, :id => parent_listed_taxon.id, :listed_taxon => {
        :establishment_means => ListedTaxon::NATIVE,
        :force_trickle_down_establishment_means => true
      }
      child_listed_taxon.reload
      expect(child_listed_taxon.establishment_means).to eq ListedTaxon::NATIVE
    end
    it "should not allow force_trickle_down_establishment_means for non-curators" do
      child_listed_taxon.update_attributes(:establishment_means => ListedTaxon::INTRODUCED)
      put :update, :format => :json, :id => parent_listed_taxon.id, :listed_taxon => {
        :establishment_means => ListedTaxon::NATIVE,
        :force_trickle_down_establishment_means => true
      }
      child_listed_taxon.reload
      expect(child_listed_taxon.establishment_means).to eq ListedTaxon::INTRODUCED
    end
  end
end

describe ListedTaxaController, "destroy" do
  it "should destroy" do
    taxon = Taxon.make!
    place = Place.make!
    check_list = List.find(place.check_list_id)
    @user = User.make!
    check_listed_taxon = check_list.add_taxon(taxon, options = {user_id: @user.id})    
    admin = make_admin
    http_login(admin)
    delete :destroy, :format => :json, :id => check_listed_taxon.id
    expect(ListedTaxon.find_by_id(check_listed_taxon.id)).to be_blank  
  end
  it "should log atlas_alterations if listed_taxa is_atlased? on destroy" do
    taxon = Taxon.make!
    atlas_place = Place.make!(admin_level: 0)
    atlas_place_check_list = List.find(atlas_place.check_list_id)
    @user = User.make!
    check_listed_taxon = atlas_place_check_list.add_taxon(taxon, options = {user_id: @user.id})
    atlas = Atlas.make!(user: @other_user, taxon: taxon)
    expect(check_listed_taxon.is_atlased?).to be true  
    admin = make_admin
    http_login(admin)
    delete :destroy, :format => :json, :id => check_listed_taxon.id
    expect(ListedTaxon.find_by_id(check_listed_taxon.id)).to be_blank  
    expect(AtlasAlteration.where(
      atlas_id: atlas.id,
      user_id: admin.id,
      place_id: atlas_place.id,
      action: "destroyed"
    ).first).not_to be_blank
  end
end
