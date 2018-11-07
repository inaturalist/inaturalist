require File.dirname(__FILE__) + '/../spec_helper'

shared_examples_for "a VotesController" do
  let(:user) { User.make! }
  before { enable_has_subscribers }
  after { disable_has_subscribers }

  describe "vote" do
    before(:each) { enable_elastic_indexing( Observation ) }
    after(:each) { disable_elastic_indexing( Observation ) }
    let(:o) { Observation.make! }
    it "should default to a positive vote" do
      post :vote, format: 'json', resource_type: 'observation', resource_id: o.id
      expect( o.get_upvotes.size ).to eq 1
    end
    it "should include votes in the respose" do
      post :vote, format: 'json', resource_type: 'observation', resource_id: o.id
      json = JSON.parse(response.body)
      expect( json['votes'].size ).to eq 1
    end
    it "should accept a scope" do
      post :vote, format: 'json', resource_type: 'observation', resource_id: o.id, scope: 'beautiful'
      expect( o.get_upvotes(vote_scope: 'beautiful').size ).to eq 1
    end
    it "should allow multiple votes per user in different scopes" do
      post :vote, format: 'json', resource_type: 'observation', resource_id: o.id
      post :vote, format: 'json', resource_type: 'observation', resource_id: o.id, scope: 'beautiful'
      expect( o.get_upvotes(vote_scope: 'beautiful').size ).to eq 1
      expect( o.votes_for.size ).to eq 2
    end

    it "should generate an update for the owner of the votable resource" do
      expect( UpdateAction.unviewed_by_user_from_query(o.user_id, resource: o) ).to eq false
      without_delay do
        post :vote, format: 'json', resource_type: 'observation', resource_id: o.id
      end
      expect( UpdateAction.unviewed_by_user_from_query(o.user_id, resource: o) ).to eq true
    end

    it "should not generate an update for the owner of the votable resource if the owner voted" do
      obs = Observation.make!( user: user )
      expect( UpdateAction.unviewed_by_user_from_query(user.id, resource: o) ).to eq false
      without_delay do
        post :vote, format: 'json', resource_type: 'observation', resource_id: obs.id
      end
      expect( UpdateAction.unviewed_by_user_from_query(user.id, resource: o) ).to eq false
    end

    it "should subscribe the voter to updates on the votable" do
      expect( Subscription.where(user: user, resource: o).count ).to eq 0
      without_delay do
        post :vote, format: 'json', resource_type: 'observation', resource_id: o.id
      end
      expect( Subscription.where(user: user, resource: o).count ).to eq 1
    end

    it "should increment cached_votes_total" do
      expect( o.cached_votes_total ).to eq 0
      post :vote, format: 'json', resource_type: 'observation', resource_id: o.id
      o.reload
      expect( o.cached_votes_total ).to eq 1
    end
  end
  
  describe "unvote" do
    let(:o) { Observation.make! }
    before do
      o.like_by user
    end
    it "should remove the vote" do
      post :unvote, format: :json, resource_type: 'observation', resource_id: o.id
      expect( o.votes_for.size ).to eq 0
    end
    it "should decrement cached_votes_total" do
      expect( o.cached_votes_total ).to eq 1
      post :unvote, format: :json, resource_type: 'observation', resource_id: o.id
      o.reload
      expect( o.cached_votes_total ).to eq 0
    end
  end
end

describe VotesController, "oauth authentication" do
  let(:token) { double :acceptable? => true, :accessible? => true, :resource_owner_id => user.id, :application => OauthApplication.make! }
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    allow(controller).to receive(:doorkeeper_token) { token }
  end
  it_behaves_like "a VotesController"
end

describe VotesController, "devise authentication" do
  before { http_login(user) }
  it_behaves_like "a VotesController"
end
