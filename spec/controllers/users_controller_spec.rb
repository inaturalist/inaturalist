require File.dirname(__FILE__) + '/../spec_helper'

describe UsersController, "delete" do
  it "should be possible for the user" do
    user = User.make
    sign_in user
    delete :destroy, :id => user.id
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
