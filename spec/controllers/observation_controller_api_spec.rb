require File.dirname(__FILE__) + '/../spec_helper'

shared_examples_for "an ObservationsController" do

  describe "create" do
    it "should create" do
      lambda {
        post :create, :format => :json, :observation => {:species_guess => "foo"}
      }.should change(Observation, :count).by(1)
      o = Observation.last
      o.user_id.should eq(user.id)
      o.species_guess.should eq ("foo")
    end

    it "should include private coordinates in create response" do
      post :create, :format => :json, :observation => {:latitude => 1.2345, :longitude => 1.2345, :geoprivacy => Observation::PRIVATE}
      o = Observation.last
      o.should be_coordinates_obscured
      response.body.should =~ /#{o.private_latitude}/
      response.body.should =~ /#{o.private_longitude}/
    end
  end

  describe "destroy" do
    it "should destroy" do
      o = Observation.make!(:user => user)
      delete :destroy, :format => :json, :id => o.id
      Observation.find_by_id(o.id).should be_blank
    end

    it "should not destory other people's observations" do
      o = Observation.make!
      delete :destroy, :format => :json, :id => o.id
      Observation.find_by_id(o.id).should_not be_blank
    end
  end

  describe "show" do
    it "should provide private coordinates for user's observation" do
      o = Observation.make!(:user => user, :latitude => 1.23456, :longitude => 7.890123, :geoprivacy => Observation::PRIVATE)
      get :show, :format => :json, :id => o.id
      response.body.should =~ /#{o.private_latitude}/
      response.body.should =~ /#{o.private_longitude}/
    end

    it "should not provide private coordinates for another user's observation" do
      o = Observation.make!(:latitude => 1.23456, :longitude => 7.890123, :geoprivacy => Observation::PRIVATE)
      get :show, :format => :json, :id => o.id
      response.body.should_not =~ /#{o.private_latitude}/
      response.body.should_not =~ /#{o.private_longitude}/
    end

    it "should not include photo metadata" do
      p = LocalPhoto.make!(:metadata => {:foo => "bar"})
      p.metadata.should_not be_blank
      o = Observation.make!(:user => p.user, :taxon => Taxon.make!)
      op = ObservationPhoto.make!(:photo => p, :observation => o)
      get :show, :format => :json, :id => o.id
      response_obs = JSON.parse(response.body)
      response_photo = response_obs['observation_photos'][0]['photo']
      response_photo.should_not be_blank
      response_photo['metadata'].should be_blank
    end
  end

  define "update" do
    it "should update" do
      o = Observation.make!(:user => user)
      put :update, :format => :json, :id => o.id, :observation => {:species_guess => "i am so updated"}
      o.reload
      o.species_guess.should eq("i am so updated")
    end
  end

  describe "by_login" do
    it "should get user's observations" do
      3.times { Observation.make!(:user => user) }
      get :by_login, :format => :json, :login => user.login
      json = JSON.parse(response.body)
      json.size.should eq(3)
    end
  end

  describe "index" do
    it "should filter by hour range" do
      o = Observation.make!(:observed_on_string => "2012-01-01 13:13")
      o.time_observed_at.should_not be_blank
      get :index, :format => :json, :h1 => 13, :h2 => 14
      json = JSON.parse(response.body)
      json.detect{|obs| obs['id'] == o.id}.should_not be_blank
    end

    it "should filter by date range" do
      o = Observation.make!(:observed_on_string => "2012-01-01 13:13")
      o.time_observed_at.should_not be_blank
      get :index, :format => :json, :d1 => "2011-12-31", :d2 => "2012-01-04"
      json = JSON.parse(response.body)
      json.detect{|obs| obs['id'] == o.id}.should_not be_blank
    end

    it "should include pagination data in headers" do
      3.times { Observation.make! }
      total_entries = Observation.count
      get :index, :format => :json, :page => 2, :per_page => 30
      response.headers["X-Total-Entries"].to_i.should eq(total_entries)
      response.headers["X-Page"].to_i.should eq(2)
      response.headers["X-Per-Page"].to_i.should eq(30)
    end

    it "should not include photo metadata" do
      p = LocalPhoto.make!(:metadata => {:foo => "bar"})
      p.metadata.should_not be_blank
      o = Observation.make!(:user => p.user, :taxon => Taxon.make!)
      op = ObservationPhoto.make!(:photo => p, :observation => o)
      get :index, :format => :json, :taxon_id => o.taxon_id
      json = JSON.parse(response.body)
      response_obs = json.detect{|obs| obs['id'] == o.id}
      response_obs.should_not be_blank
      response_photo = response_obs['photos'].first
      response_photo.should_not be_blank
      response_photo['metadata'].should be_blank
    end

    it "should filter by conservation_status" do
      cs = without_delay {ConservationStatus.make!}
      t = cs.taxon
      o1 = Observation.make!(:taxon => t)
      o2 = Observation.make!(:taxon => Taxon.make!)
      get :index, :format => :json, :cs => cs.status
      json = JSON.parse(response.body)
      json.detect{|obs| obs['id'] == o1.id}.should_not be_blank
      json.detect{|obs| obs['id'] == o2.id}.should be_blank
    end

    it "should filter by conservation_status authority" do
      cs1 = without_delay {ConservationStatus.make!(:authority => "foo")}
      cs2 = without_delay {ConservationStatus.make!(:authority => "bar", :status => cs1.status)}
      o1 = Observation.make!(:taxon => cs1.taxon)
      o2 = Observation.make!(:taxon => cs2.taxon)
      get :index, :format => :json, :csa => cs1.authority
      json = JSON.parse(response.body)
      json.detect{|obs| obs['id'] == o1.id}.should_not be_blank
      json.detect{|obs| obs['id'] == o2.id}.should be_blank
    end

    it "should filter by establishment means" do
      p = make_place_with_geom
      lt1 = without_delay {ListedTaxon.make!(:establishment_means => ListedTaxon::INTRODUCED, :list => p.check_list, :place => p)}
      lt2 = without_delay {ListedTaxon.make!(:establishment_means => ListedTaxon::NATIVE, :list => p.check_list, :place => p)}
      o1 = Observation.make!(:taxon => lt1.taxon, :latitude => p.latitude, :longitude => p.longitude)
      o2 = Observation.make!(:taxon => lt2.taxon, :latitude => p.latitude, :longitude => p.longitude)
      get :index, :format => :json, :establishment_means => lt1.establishment_means, :place_id => p.id
      json = JSON.parse(response.body)
      json.detect{|obs| obs['id'] == o1.id}.should_not be_blank
      json.detect{|obs| obs['id'] == o2.id}.should be_blank
    end
  end
end

describe ObservationsController, "oauth authentication" do
  let(:user) { User.make! }
  let(:token) { stub :accessible? => true, :resource_owner_id => user.id }
  before do
    controller.stub(:doorkeeper_token) { token }
  end
  it_behaves_like "an ObservationsController"
end

describe ObservationsController, "devise authentication" do
  let(:user) { User.make! }
  before do
    http_login(user)
  end
  it_behaves_like "an ObservationsController"
end
