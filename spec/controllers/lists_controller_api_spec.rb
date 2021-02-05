require File.dirname(__FILE__) + '/../spec_helper'

describe ListsController, "show" do
  elastic_models( Observation )
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

    user = UserPrivilege.make!( privilege: UserPrivilege::ORGANIZER ).user
    sign_in user
    place = make_place_with_geom(user: user)
    place.save_geom( GeoRuby::SimpleFeatures::Geometry.from_ewkt( "MULTIPOLYGON(((0 0,0 1,1 1,1 0,0 0)))" ) )

    post :create, list: { title: "foo", type: "CheckList"}, place: place.id
    list = List.where(place_id: place.id).last

    lt1 = ListedTaxon.make!(taxon: t1, list: list)
    lt2 = ListedTaxon.make!(taxon: t2, list: list)
    expect(lt1.observations_count).to eq 0
    expect(lt2.observations_count).to eq 0
    without_delay do
      Observation.make!( taxon: t1, user: user, latitude: 0.5, longitude: 0.5 )
      #make_research_grade_observation( taxon: t1, user: user, latitude: 0.5, longitude: 0.5 )
      2.times { Observation.make!( taxon: t2, user: user, latitude: 0.5, longitude: 0.5 ) }
      #2.times { make_research_grade_observation( taxon: t2, user: user, latitude: 0.5, longitude: 0.5 ) }
    end
    lt1.reload
    expect(lt1.observations_count).to eq 0
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
