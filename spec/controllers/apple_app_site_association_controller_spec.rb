# frozen_string_literal: true

require "#{File.dirname( __FILE__ )}/../spec_helper"

describe AppleAppSiteAssociationController do
  it "should 404 if preference not set for site" do
    allow( CONFIG ).to receive( :apple ).and_return OpenStruct.new
    site = Site.make!
    expect( site.preferred_ios_app_webcredentials ).to be_blank
    expect( CONFIG.apple.team_id ).to be_blank
    get :index, params: { inat_site_id: site.id }
    expect( response.status ).to eq 404
  end

  it "should return the webcredentials if set for site" do
    s = Site.make!( preferred_ios_app_webcredentials: "foo" )
    get :index, params: { inat_site_id: s.id }
    expect( JSON.parse( response.body )["webcredentials"]["apps"][0] ).to eq "foo"
  end

  it "should return the applinks if set in config" do
    allow( CONFIG ).to receive_message_chain( :apple, :team_id ) { "inat-team-ID" }
    allow( CONFIG ).to receive_message_chain( :apple, :applinks ) do
      {
        "org.inaturalist.bundle": [
          "/path/to/something"
        ]
      }
    end
    get :index
    expect(
      JSON.parse( response.body )["applinks"]["details"][0]["appID"]
    ).to eq "#{CONFIG.apple.team_id}.#{CONFIG.apple.applinks.keys[0]}"
    expect(
      JSON.parse( response.body )["applinks"]["details"][0]["paths"]
    ).to include CONFIG.apple.applinks.values[0][0]
  end
end
