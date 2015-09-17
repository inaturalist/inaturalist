require File.dirname(__FILE__) + '/../spec_helper'

shared_examples_for "a signed in UsersController" do
  before(:each) { enable_elastic_indexing( Update ) }
  after(:each) { disable_elastic_indexing( Update ) }
  let(:user) { User.make! }
  it "should show email for edit" do
    get :edit, :format => :json
    expect(response).to be_success
    expect(response.body).to be =~ /#{user.email}/
  end

  it "should show the dashboard" do
    get :dashboard
    expect(response).to be_success
  end

  describe "new_updates" do
    it "should show recent updates" do
      o = Observation.make!(:user => user)
      without_delay { Comment.make!(:parent => o) }
      get :new_updates, :format => :json
      json = JSON.parse(response.body)
      expect(json.size).to be > 0
    end

    it "return mentions" do
      without_delay { Comment.make!(body: "hey @#{ user.login }") }
      get :new_updates, format: :json, notification: "mention"
      json = JSON.parse(response.body)
      expect(json.size).to be > 0
      expect(json.first["notification"]).to eq "mention"
    end

    it "should filter by resource_type" do
      p = Post.make!(:parent => user, :user => user)
      without_delay { Comment.make!(:parent => p) }
      get :new_updates, :format => :json, :resource_type => "Post"
      json = JSON.parse(response.body)
      expect(json.size).to be > 0

      get :new_updates, :format => :json, :resource_type => "Observation"
      json = JSON.parse(response.body)
      expect(json).to be_blank
      expect(json.size).to eq 0
    end

    it "should filter by notifier_type" do
      o = Observation.make!(:user => user)
      without_delay { Comment.make!(:parent => o) }
      get :new_updates, :format => :json, :notifier_type => "Comment"
      json = JSON.parse(response.body)
      expect(json.size).to be > 0

      get :new_updates, :format => :json, :notifier_type => "Identification"
      json = JSON.parse(response.body)
      expect(json).to be_blank
      expect(json.size).to eq 0
    end

    it "should allow user to skip marking the updates as viewed" do
      o = Observation.make!(:user => user)
      without_delay { Comment.make!(:parent => o) }
      get :new_updates, :format => :json, :skip_view => true
      Delayed::Worker.new(:quiet => true).work_off
      expect(user.updates.unviewed.activity.count).to be > 0
    end
  end

  describe "search" do
    it "should search by username" do
      u = User.make!
      get :search, :q => u.login, :format => :json
      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json.detect{|ju| ju['id'] == u.id}).not_to be_blank
    end

    it "should allow email searches" do
      u = User.make!
      get :search, :q => u.email, :format => :json
      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json.detect{|ju| ju['id'] == u.id}).not_to be_blank
    end
  end
end

describe UsersController, "oauth authentication" do
  let(:token) { double :acceptable? => true, :accessible? => true, :resource_owner_id => user.id }
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    allow(controller).to receive(:doorkeeper_token) { token }
  end
  it_behaves_like "a signed in UsersController"
end

describe UsersController, "devise authentication" do
  before do
    http_login user
  end
  it_behaves_like "a signed in UsersController"
end

describe UsersController, "without authentication" do
  it "should not show email for edit" do
    user = User.make!
    get :edit, :format => :json, :id => user.id
    expect(response).not_to be_success
    expect(response.body).not_to be =~ /#{user.email}/
  end

  describe "search" do
    it "should search by username" do
      u1 = User.make!(:login => "foo")
      u2 = User.make!(:login => "bar")
      get :search, :q => u1.login, :format => :json
      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json.detect{|ju| ju['id'] == u1.id}).not_to be_blank
      expect(json.detect{|ju| ju['id'] == u2.id}).to be_blank
    end
    
    it "should not allow email searches" do
      u = User.make!
      get :search, :q => u.email, :format => :json
      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json).to be_blank
    end

    it "can order by activity" do
      u1 = User.make!(login: "aaa", observations_count: 2)
      u2 = User.make!(login: "abb", observations_count: 1)
      u3 = User.make!(login: "acc", observations_count: 3)
      get :search, q: "a", format: :json
      expect(JSON.parse(response.body).map{ |r| r["login"] }).to eq [ "aaa", "abb", "acc" ]
      get :search, q: "a", format: :json, order: "activity"
      expect(JSON.parse(response.body).map{ |r| r["login"] }).to eq [ "acc", "aaa", "abb" ]
    end
  end
end
