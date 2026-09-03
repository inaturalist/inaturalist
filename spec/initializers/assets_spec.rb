# frozen_string_literal: true

require "spec_helper"

describe "asset pipeline" do
  it "declares the Google Earth KML styles as a precompiled asset" do
    assets = Rails.application.assets
    manifest = assets.find_asset( "manifest.js" )
    kml = assets.find_asset( "observations/google_earth.kml" )

    expect( manifest ).not_to be_nil
    expect( kml ).not_to be_nil
    expect( manifest.links ).to include( kml.uri )
  end
end
