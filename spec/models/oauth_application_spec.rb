# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe OauthApplication do
  # NOTE: this spec will NOT work with zeus, since it will have Doorkeeper
  # and its default config values loaded before we stub the Rails.env so
  # stubbing it won't make a difference
  it "should allow a non-https redirect_uri in production" do
    allow(Rails).to receive('env').and_return('production')
    expect( OauthApplication.make(redirect_uri: 'http://www.inaturalist.org') ).to be_valid
  end

  it "should not allow params in the redirect_uri" do
    expect( OauthApplication.make( redirect_uri: "http://www.inaturalist.org/foo?bar=baz" ) ).not_to be_valid
  end

  it "should have default scopes by default" do
    expect( OauthApplication.make!.scopes.to_s ).to eq Doorkeeper.configuration.default_scopes.to_s
  end
end
