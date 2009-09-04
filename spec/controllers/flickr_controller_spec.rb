require File.dirname(__FILE__) + '/../spec_helper'

describe FlickrController do
  
  before(:each) do
    controller.stub!(:login_required)
  end
  
  # TODO: There are no flickr fixtures!
  it "should redirect when no frob is provided" do
    get 'authorize'
    response.should redirect_to(:action => 'options')
  end
  
  it "should not redirect when a frob is provided" do
    get 'authorize', {:frob => '1234abcd'}
    response.should be_success
  end

end
