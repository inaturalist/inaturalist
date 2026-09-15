# frozen_string_literal: true

require "spec_helper"

describe "the admin feature flag readout", type: :request do
  include Devise::Test::IntegrationHelpers

  let( :admin ) { make_admin }

  before do
    sign_in admin
    add_test_flags
  end

  it "links to the flag admin UI" do
    get "/admin"
    expect( response.response_code ).to eq 200
    expect( response.body ).to include "/admin/feature_flags"
  end

  it "reports the pilot flag as off by default" do
    get "/admin"
    expect( response.body ).to match( %r{<code>client_smoke_test</code>.*<strong>false</strong>}m )
  end

  it "reports the pilot flag as on once enabled for the admin" do
    Flipper.enable_actor( :client_smoke_test, admin )
    get "/admin"
    expect( response.body ).to match( %r{<code>client_smoke_test</code>.*<strong>true</strong>}m )
  end

  it "reflects a percentage rollout without a restart" do
    Flipper.enable_percentage_of_actors( :client_smoke_test, 100 )
    get "/admin"
    expect( response.body ).to match( %r{<code>client_smoke_test</code>.*<strong>true</strong>}m )
  end

  it "lists a server-only flag" do
    get "/admin"
    expect( response.body ).to include "<code>server_smoke_test</code>"
    expect( response.body ).to include I18n.t( :feature_flags_kind_server )
  end

  it "lists a flag created at runtime" do
    Flipper.add( :client_brand_new )
    get "/admin"
    expect( response.body ).to include "<code>client_brand_new</code>"
  end

  it "shows the experiment under its bare name" do
    get "/admin"
    expect( response.body ).to include I18n.t( :feature_flags_your_variant, experiment: "hello_world" )
  end

  it "shows the admin as unenrolled in the experiment by default" do
    get "/admin"
    expect( response.body ).to include I18n.t( :feature_flags_not_enrolled )
  end

  it "shows an assigned variant once the experiment flag is on" do
    Flipper.enable( :exp_hello_world )
    get "/admin"
    expect( response.body ).not_to include I18n.t( :feature_flags_not_enrolled )
    expect( response.body ).to match( %r{<strong>(control|treatment)</strong>} )
  end

  it "renders an empty state when no flags exist" do
    Flipper.instance = Flipper.new( Flipper::Adapters::Memory.new )
    get "/admin"
    expect( response.body ).to include I18n.t( :feature_flags_none_html, url: "/admin/feature_flags" )
  end
end

# Controller spec required; admin_required filter's throw :abort escapes integration stack as UncaughtThrowError.
describe AdminController, type: :controller do
  render_views

  # Catch required; throw :abort escapes callback chain as UncaughtThrowError (pre-existing admin filter behavior).
  it "does not show the flag readout to non-admins" do
    sign_in User.make!
    catch( :abort ) { get :index }
    expect( response ).to be_redirect
    expect( response.body ).not_to include "client_smoke_test"
  end

  it "shows the flag readout to admins" do
    sign_in make_admin
    add_test_flags
    get :index
    expect( response.body ).to include "client_smoke_test"
  end
end
