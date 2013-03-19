require File.dirname(__FILE__) + '/../spec_helper'

describe UsersController, "dashboard" do
  it "should be accessible when signed in" do
    user = User.make!
    sign_in user
    get :dashboard
    response.should be_success
  end
end

describe UsersController, "create" do
  it "should not work" do
    lambda {
      post :create, :user => {:login => "foo", :password => "bar", :password_confirmation => "bar"}
    }.should_not change(User, :count).by(1)
  end
end

describe UsersController, "delete" do
  it "should be possible for the user" do
    user = User.make!
    sign_in user
    without_delay { delete :destroy, :id => user.id }
    response.should be_redirect
    User.find_by_id(user.id).should be_blank
  end
  
  it "should be impossible for everyone else" do
    user = User.make!
    nogoodnik = User.make!
    sign_in nogoodnik
    delete :destroy, :id => user.id
    User.find_by_id(user.id).should_not be_blank
  end
end
