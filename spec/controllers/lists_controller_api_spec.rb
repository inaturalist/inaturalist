require File.dirname(__FILE__) + '/../spec_helper'

describe ListsController, "show" do
  elastic_models( Observation )
  let(:lt) { ListedTaxon.make! }
  before do
    sign_in User.make!
  end
  it "should include a list" do
    get :show, :format => :json, :id => lt.list_id
    json = JSON.parse(response.body)
    expect(json['list']).not_to be_blank
  end

  it "should filter by taxon" do
    parent = Taxon.make!(rank: Taxon::GENUS)
    lt1 = ListedTaxon.make!(taxon: Taxon.make!(parent: parent, rank: Taxon::SPECIES))
    expect(parent.children.size).to eq 1
    lt2 = ListedTaxon.make!(:list => lt1.list)
    get :show, :format => :json, :id => lt1.list_id, :taxon => parent.id
    json = JSON.parse(response.body)
    expect(json['listed_taxa'].size).to eq 1
    expect(json['listed_taxa'][0]['id']).to eq lt1.id
  end

  it "should allow sort by name" do
    lt0 = ListedTaxon.make!(:taxon => Taxon.make!(:name => "Cuthona"))
    lt1 = ListedTaxon.make!(:taxon => Taxon.make!(:name => "Amelanchier"), :list => lt0.list)
    lt2 = ListedTaxon.make!(:taxon => Taxon.make!(:name => "Bothrops"), :list => lt0.list)
    without_delay do
      Observation.make!(:taxon => lt1.taxon, :user => lt1.list.user)
      2.times { Observation.make!(:taxon => lt2.taxon, :user => lt1.list.user) }
    end
    get :show, :format => :json, :id => lt1.list_id, :order_by => "name"
    json = JSON.parse(response.body)
    expect(json['listed_taxa'].size).to eq 3
    expect(json['listed_taxa'][0]['id']).to eq lt1.id
  end

  it "per_page should work" do
    lt0 = ListedTaxon.make!(:taxon => Taxon.make!(:name => "Cuthona"))
    lt1 = ListedTaxon.make!(:taxon => Taxon.make!(:name => "Amelanchier"), :list => lt0.list)
    lt2 = ListedTaxon.make!(:taxon => Taxon.make!(:name => "Bothrops"), :list => lt0.list)
    get :show, :format => :json, :id => lt1.list_id, :order_by => "name", :per_page => 1
    json = JSON.parse(response.body)
    expect(json['listed_taxa'].size).to eq 1
  end
end
