require File.dirname(__FILE__) + '/../spec_helper'

describe PlacesController, "index" do

  it "should return places" do
    p = Place.make!
    get :index, :format => :json
    expect(response.body).to be =~ /#{p.name}/
  end

  it "should return places where taxa occur" do
    p = Place.make!
    t = Taxon.make!
    lt = p.check_list.add_taxon(t)
    get :index, :format => :json, :taxon => t.name
    expect(response.body).to be =~ /#{p.name}/
  end

  it "should not return places where taxa do not occur" do
    p1 = Place.make!
    p2 = Place.make!
    t = Taxon.make!
    lt = p1.check_list.add_taxon(t)
    get :index, :format => :json, :taxon => t.name
    expect(response.body).not_to be =~ /#{p2.name}/
  end

  it "should return places where taxa occur with establishment means" do
    t = Taxon.make!
    native_place = Place.make!
    native_place.check_list.add_taxon(t, :establishment_means => ListedTaxon::NATIVE)
    introduced_place = Place.make!
    introduced_place.check_list.add_taxon(t, :establishment_means => ListedTaxon::INTRODUCED)
    get :index, :format => :json, :taxon => t.name, :establishment_means => ListedTaxon::NATIVE
    expect(response.body).to be =~ /#{native_place.name}/
    expect(response.body).not_to be =~ /#{introduced_place.name}/
  end

  it "should include endemics in searches for native" do
    p = Place.make!
    t = Taxon.make!
    lt = p.check_list.add_taxon(t, :establishment_means => ListedTaxon::ENDEMIC)
    get :index, :format => :json, :taxon => t.name, :establishment_means => ListedTaxon::NATIVE
    expect(response.body).to be =~ /#{p.name}/
  end

  it "should return places with geometries intersecting lat/lon" do
    p1 = make_place_with_geom(:wkt => "MULTIPOLYGON(((0 0,0 1,1 1,1 0,0 0)))")
    p2 = make_place_with_geom(:wkt => "MULTIPOLYGON(((0.25 0.25,0.25 1.25,1.25 1.25,1.25 0.25,0.25 0.25)))")
    get :index, :format => :json, :latitude => 0.5, :longitude => 0.5
    expect(response.body).to be =~ /#{p1.name}/
    expect(response.body).to be =~ /#{p2.name}/
    json = JSON.parse(response.body)
    expect(json.size).to eq 2
  end

  it "should not return places without geometries intersecting lat/lon" do
    p1 = Place.make!
    p2 = make_place_with_geom(:wkt => "MULTIPOLYGON(((0.25 0.25,0.25 1.25,1.25 1.25,1.25 0.25,0.25 0.25)))")
    get :index, :format => :json, :latitude => -0.5, :longitude => -0.5
    expect(response.body).not_to be =~ /#{p1.name}/
    expect(response.body).not_to be =~ /#{p2.name}/
    json = JSON.parse(response.body)
    expect(json.size).to eq 0
  end
end

describe PlacesController, "search" do
  before { enable_elastic_indexing(Place) }
  after { disable_elastic_indexing(Place) }
  it "should filter by with_geom" do
    with_geom = make_place_with_geom
    without_geom = Place.make!(name: with_geom.name)
    get :search, format: :json, with_geom: true, q: with_geom.name
    json = JSON.parse(response.body)
    expect( json.select{|p| p['id'] == with_geom.id}.size ).to eq 1
    expect( json.select{|p| p['id'] == without_geom.id}.size ).to eq 0
    get :search, format: :json, with_geom: false, q: with_geom.name
    json = JSON.parse(response.body)
    expect( json.select{|p| p['id'] == with_geom.id}.size ).to eq 0
    expect( json.select{|p| p['id'] == without_geom.id}.size ).to eq 1
  end
end


describe PlacesController, "autocomplete" do
  before { enable_elastic_indexing(Place) }
  after { disable_elastic_indexing(Place) }
  it "be able to find places with short words and diacritics" do
    place = Place.make!(name: "Área de Protección de Flora y Fauna Laguna de Términos")
    get :autocomplete, format: :json, q: "Área"
    expect( JSON.parse(response.body).first["id"] ).to eq place.id
    get :autocomplete, format: :json, q: "Área de"
    expect( JSON.parse(response.body).first["id"] ).to eq place.id
    get :autocomplete, format: :json, q: "Área de Protección"
    expect( JSON.parse(response.body).first["id"] ).to eq place.id
    get :autocomplete, format: :json, q: "Área de Protección de Flora y Fauna Laguna de Términos"
    expect( JSON.parse(response.body).first["id"] ).to eq place.id
  end

  it "should filter by with_geom" do
    p1 = make_place_with_geom
    p2 = Place.make!( name: p1.name )
    Delayed::Worker.new.work_off
    json = get :autocomplete, format: :json, q: p1.name, with_geom: true
    json = JSON.parse( response.body )
    expect( json.size ).to eq 1
  end
  it "should filter by with_checklist" do
    p1 = Place.make!( prefers_check_lists: false )
    p2 = Place.make!( name: p1.name )
    Delayed::Worker.new.work_off
    p1.reload
    p2.reload
    expect( p1.check_list ).to be_blank
    expect( p2.check_list ).not_to be_blank
    json = get :autocomplete, format: :json, q: p1.name, with_check_list: true
    json = JSON.parse( response.body )
    expect( json.size ).to eq 1
  end
end
