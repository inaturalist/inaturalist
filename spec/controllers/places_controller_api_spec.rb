require File.dirname(__FILE__) + '/../spec_helper'

describe PlacesController, "index" do
  # let(:user) { User.make! }
  # let(:token) { double :acceptable? => true, :accessible? => true, :resource_owner_id => user.id }
  # before do
  #   controller.stub(:doorkeeper_token) { token }
  # end
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
