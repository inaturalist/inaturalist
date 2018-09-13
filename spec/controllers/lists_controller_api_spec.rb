require File.dirname(__FILE__) + '/../spec_helper'

describe ListsController, "show" do
  before(:each) { enable_elastic_indexing( Observation ) }
  after(:each) { disable_elastic_indexing( Observation ) }
  let(:lt) { ListedTaxon.make! }
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

  it "should default to ordering by observations_count desc" do
    t1 = Taxon.make!(:rank => Taxon::SPECIES)
    t2 = Taxon.make!(:rank => Taxon::SPECIES)
    lt1 = ListedTaxon.make!(:taxon => t1)
    lt2 = ListedTaxon.make!(:taxon => t2, :list => lt1.list)
    without_delay do
      Observation.make!(:taxon => lt1.taxon, :user => lt1.list.user)
      2.times { Observation.make!(:taxon => lt2.taxon, :user => lt2.list.user) }
    end
    lt1.reload
    expect(lt1.observations_count).to eq 1
    lt2.reload
    expect(lt2.observations_count).to eq 2
    get :show, :format => :json, :id => lt1.list_id
    json = JSON.parse(response.body)
    expect(json['listed_taxa'].size).to eq 2
    expect(json['listed_taxa'][0]['id']).to eq lt2.id
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
