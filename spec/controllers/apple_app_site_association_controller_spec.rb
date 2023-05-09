require File.dirname(__FILE__) + "/../spec_helper"

describe AppleAppSiteAssociationController do
  it "should 404 if preference not set for site" do
    s = Site.make!
    get :index, params: { inat_site_id: s.id }
    expect( response.status ).to eq 404
  end
  it "should return the webcredentials if set for site" do
    s = Site.make!( preferred_ios_app_webcredentials: "foo" )
    get :index, params: { inat_site_id: s.id }
    expect( JSON.parse( response.body )["webcredentials"]["apps"][0] ).to eq "foo"
  end
end
