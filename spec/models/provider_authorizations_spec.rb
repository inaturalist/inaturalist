require File.expand_path("../../spec_helper", __FILE__)

describe ProviderAuthorization, "creation" do
  it "should not allow multiple authorizations per user per provider" do
    pa = ProviderAuthorization.make!( provider_name: "flickr", provider_uid: "foo" )
    expect( pa ).to be_valid
    expect(
      ProviderAuthorization.make(
        provider_name: "flickr",
        provider_uid: "bar",
        user: pa.user
      )
    ).not_to be_valid
  end

  it "should not allow multiple authorizations per user per openid provider" do
    pa = ProviderAuthorization.make!(
      provider_name: "openid",
      provider_uid: "https://www.google.com/accounts/o8/id?id=xxx"
    )
    expect( pa ).to be_valid
    expect( ProviderAuthorization.make(
      provider_name: "openid",
      provider_uid: "https://www.google.com/accounts/o8/id?id=yyy",
      user: pa.user
    ) ).not_to be_valid
  end

  it "should allow multiple openid authorizations" do
    pa = ProviderAuthorization.make!(
      provider_name: "openid",
      provider_uid: "https://www.google.com/accounts/o8/id?id=xxx"
    )
    expect( pa ).to be_valid
    expect( ProviderAuthorization.make(
      provider_name: "openid",
      provider_uid: "https://me.yahoo.com/a/xxx",
      user: pa.user
    ) ).to be_valid
  end
end
