require File.dirname(__FILE__) + '/../spec_helper'

shared_examples_for "a signed in UsersController" do
  let(:user) { User.make! }
  it "should show email for edit" do
    get :edit, :format => :json
    response.should be_success
    response.body.should =~ /#{user.email}/
  end

  it "should show the dashboard" do
    get :dashboard
    response.should be_success
  end

  describe "new_updates" do
    it "should show recent updates" do
      o = Observation.make!(:user => user)
      without_delay { Comment.make!(:parent => o) }
      get :new_updates, :format => :json
      json = JSON.parse(response.body)
      json.size.should > 0
    end

    it "should filter by resource_type" do
      p = Post.make!(:parent => user, :user => user)
      without_delay { Comment.make!(:parent => p) }
      get :new_updates, :format => :json, :resource_type => "Post"
      json = JSON.parse(response.body)
      json.size.should > 0

      get :new_updates, :format => :json, :resource_type => "Observation"
      json = JSON.parse(response.body)
      json.should be_blank
      json.size.should eq 0
    end

    it "should filter by notifier_type" do
      o = Observation.make!(:user => user)
      without_delay { Comment.make!(:parent => o) }
      get :new_updates, :format => :json, :notifier_type => "Comment"
      json = JSON.parse(response.body)
      json.size.should > 0

      get :new_updates, :format => :json, :notifier_type => "Identification"
      json = JSON.parse(response.body)
      json.should be_blank
      json.size.should eq 0
    end

    it "should allow user to skip marking the updates as viewed" do
      o = Observation.make!(:user => user)
      without_delay { Comment.make!(:parent => o) }
      get :new_updates, :format => :json, :skip_view => true
      Delayed::Worker.new(:quiet => true).work_off
      user.updates.unviewed.activity.count.should > 0
    end
  end

  describe "search" do
    it "should search by username" do
      u = User.make!
      get :search, :q => u.login, :format => :json
      response.should be_success
      json = JSON.parse(response.body)
      json.detect{|ju| ju['id'] == u.id}.should_not be_blank
    end

    it "should allow email searches" do
      u = User.make!
      get :search, :q => u.email, :format => :json
      response.should be_success
      json = JSON.parse(response.body)
      json.detect{|ju| ju['id'] == u.id}.should_not be_blank
    end
  end
end

describe UsersController, "oauth authentication" do
  let(:token) { double :acceptable? => true, :accessible? => true, :resource_owner_id => user.id }
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    controller.stub(:doorkeeper_token) { token }
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
    response.should_not be_success
    response.body.should_not =~ /#{user.email}/
  end

  describe "search" do
    it "should search by username" do
      u1 = User.make!(:login => "foo")
      u2 = User.make!(:login => "bar")
      get :search, :q => u1.login, :format => :json
      response.should be_success
      json = JSON.parse(response.body)
      json.detect{|ju| ju['id'] == u1.id}.should_not be_blank
      json.detect{|ju| ju['id'] == u2.id}.should be_blank
    end
    
    it "should not allow email searches" do
      u = User.make!
      get :search, :q => u.email, :format => :json
      response.should be_success
      json = JSON.parse(response.body)
      json.should be_blank
    end
  end
end
