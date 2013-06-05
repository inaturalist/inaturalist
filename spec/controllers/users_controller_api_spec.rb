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
end

describe UsersController, "oauth authentication" do
  let(:token) { stub :accessible? => true, :resource_owner_id => user.id }
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
end
