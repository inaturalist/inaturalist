require File.dirname(__FILE__) + '/../spec_helper'

describe PlacesController, "index" do
  # let(:user) { User.make! }
  # let(:token) { stub :accessible? => true, :resource_owner_id => user.id }
  # before do
  #   controller.stub(:doorkeeper_token) { token }
  # end
  it "should return places" do
    p = Place.make!
    get :index, :format => :json
    response.body.should =~ /#{p.name}/
  end

  it "should return places where taxa occur" do
    p = Place.make!
    t = Taxon.make!
    lt = p.check_list.add_taxon(t)
    get :index, :format => :json, :taxon => t.name
    response.body.should =~ /#{p.name}/
  end

  it "should not return places where taxa do not occur" do
    p1 = Place.make!
    p2 = Place.make!
    t = Taxon.make!
    lt = p1.check_list.add_taxon(t)
    get :index, :format => :json, :taxon => t.name
    response.body.should_not =~ /#{p2.name}/
  end

  it "should return places where taxa occur with establishment means" do
    t = Taxon.make!
    native_place = Place.make!
    native_place.check_list.add_taxon(t, :establishment_means => ListedTaxon::NATIVE)
    introduced_place = Place.make!
    introduced_place.check_list.add_taxon(t, :establishment_means => ListedTaxon::INTRODUCED)
    get :index, :format => :json, :taxon => t.name, :establishment_means => ListedTaxon::NATIVE
    response.body.should =~ /#{native_place.name}/
    response.body.should_not =~ /#{introduced_place.name}/
  end

  it "should include endemics in searches for native" do
    p = Place.make!
    t = Taxon.make!
    lt = p.check_list.add_taxon(t, :establishment_means => ListedTaxon::ENDEMIC)
    get :index, :format => :json, :taxon => t.name, :establishment_means => ListedTaxon::NATIVE
    response.body.should =~ /#{p.name}/
  end
end
