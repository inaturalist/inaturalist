require File.dirname(__FILE__) + '/../spec_helper'

shared_examples_for "an ObservationsController" do
  it "should create" do
    lambda {
      post :create, :format => :json, :observation => {:species_guess => "foo"}
    }.should change(Observation, :count).by(1)
    o = Observation.last
    o.user_id.should eq(user.id)
    o.species_guess.should eq ("foo")
  end

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

  it "should update" do
    o = Observation.make!(:user => user)
    put :update, :format => :json, :id => o.id, :observation => {:species_guess => "i am so updated"}
    o.reload
    o.species_guess.should eq("i am so updated")
  end

  it "should get user's observations" do
    3.times { Observation.make!(:user => user) }
    get :by_login, :format => :json, :login => user.login
    json = JSON.parse(response.body)
    json.size.should eq(3)
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
    sign_in user
  end
  it_behaves_like "an ObservationsController"
end
