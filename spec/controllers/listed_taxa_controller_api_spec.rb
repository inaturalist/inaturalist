require File.dirname(__FILE__) + '/../spec_helper'

describe ListedTaxaController, "create" do
  render_views
  let(:user) { User.make! }
  let(:list) { List.make!(:user => user) }
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
