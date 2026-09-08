# frozen_string_literal: true

require "spec_helper"

describe "the admin feature flag readout", type: :request do
  include Devise::Test::IntegrationHelpers

  let( :admin ) { make_admin }

  before { sign_in admin }

  it "links to the flag admin UI" do
    get "/admin"
    expect( response.response_code ).to eq 200
    expect( response.body ).to include "/admin/feature_flags"
  end

  it "reports the pilot flag as off by default" do
    get "/admin"
    expect( response.body ).to match( %r{<code>flipper_smoke_test</code>.*<strong>false</strong>}m )
  end

  it "reports the pilot flag as on once enabled for the admin" do
    Flipper.enable_actor( :flipper_smoke_test, admin )
    get "/admin"
    expect( response.body ).to match( %r{<code>flipper_smoke_test</code>.*<strong>true</strong>}m )
  end

  it "reflects a percentage rollout without a restart" do
    Flipper.enable_percentage_of_actors( :flipper_smoke_test, 100 )
    get "/admin"
    expect( response.body ).to match( %r{<code>flipper_smoke_test</code>.*<strong>true</strong>}m )
  end

  it "shows the admin as unenrolled in the experiment by default" do
    get "/admin"
    expect( response.body ).to include "not enrolled"
  end

  it "shows an assigned variant once the experiment flag is on" do
    Flipper.enable( :exp_hello_world )
    get "/admin"
    expect( response.body ).not_to include "not enrolled"
    expect( response.body ).to match( %r{<strong>(control|treatment)</strong>} )
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
    expect( response.body ).not_to include "flipper_smoke_test"
  end

  it "shows the flag readout to admins" do
    sign_in make_admin
    get :index
    expect( response.body ).to include "flipper_smoke_test"
  end
end
