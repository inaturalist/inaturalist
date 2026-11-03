# frozen_string_literal: true

require "spec_helper"

describe "the admin feature flag readout", type: :request do
  include Devise::Test::IntegrationHelpers

  let( :admin ) { make_admin }
  let( :path ) { "/admin/feature_flags" }
  let( :flipper_path ) { "/admin/feature_flags/flipper" }

  before do
    sign_in admin
    add_test_flags
  end

  it "renders in the admin layout" do
    get path
    expect( response.response_code ).to eq 200
    expect( response.body ).to include "nav-sidebar"
  end

  it "links to the Flipper UI" do
    get path
    expect( response.body ).to include %(href="#{flipper_path}")
  end

  it "is linked from the admin sidebar" do
    get "/admin"
    expect( response.body ).to include %(href="#{path}")
  end

  it "no longer renders the readout on the admin index" do
    get "/admin"
    expect( response.body ).not_to include "client_smoke_test"
  end

  it "reports the pilot flag as off by default" do
    get path
    expect( response.body ).to match( %r{<code>client_smoke_test</code>.*<strong>false</strong>}m )
  end

  it "reports the pilot flag as on once enabled for the admin" do
    Flipper.enable_actor( :client_smoke_test, admin )
    get path
    expect( response.body ).to match( %r{<code>client_smoke_test</code>.*<strong>true</strong>}m )
  end

  it "reflects a percentage rollout without a restart" do
    Flipper.enable_percentage_of_actors( :client_smoke_test, 100 )
    get path
    expect( response.body ).to match( %r{<code>client_smoke_test</code>.*<strong>true</strong>}m )
  end

  it "lists a server-only flag" do
    get path
    expect( response.body ).to include "<code>server_smoke_test</code>"
    expect( response.body ).to include I18n.t( :feature_flags_kind_server )
  end

  it "lists a flag created at runtime" do
    Flipper.add( :client_brand_new )
    get path
    expect( response.body ).to include "<code>client_brand_new</code>"
  end

  it "shows the experiment under its bare name" do
    get path
    expect( response.body ).to include I18n.t( :feature_flags_your_variant, experiment: "hello_world" )
  end

  it "shows the admin as unenrolled in the experiment by default" do
    get path
    expect( response.body ).to include I18n.t( :feature_flags_not_enrolled )
  end

  it "shows an assigned variant once the experiment flag is on" do
    Flipper.enable( :exp_hello_world )
    get path
    expect( response.body ).not_to include I18n.t( :feature_flags_not_enrolled )
    expect( response.body ).to match( %r{<strong>(control|treatment)</strong>} )
  end

  describe "the installation preview" do
    let( :installation_id ) { SecureRandom.uuid }
    let( :label ) { I18n.t( :feature_flags_for_installation ) }

    before { add_install_test_flags }

    it "offers an installation id field" do
      get path
      expect( response.body ).to include %(name="installation_id")
    end

    it "offers a clear button that drops the entered id" do
      get path, params: { installation_id: installation_id }
      expect( response.body ).to match( %r{<a[^>]*href="#{path}"[^>]*>#{I18n.t( :feature_flags_clear )}</a>} )
    end

    it "marks install-scoped flags" do
      get path
      expect( response.body ).
        to match( %r{<code>client_install_smoke_test</code>.*#{I18n.t( :feature_flags_by_installation )}}m )
    end

    it "shows nothing for an installation until one is entered" do
      get path
      expect( response.body ).not_to include I18n.t( :feature_flags_for_installation )
    end

    it "shows an installation's percentage result" do
      Flipper.enable_percentage_of_actors( :client_install_smoke_test, 100 )
      get path, params: { installation_id: installation_id }
      expect( response.body ).to include I18n.t( :feature_flags_for_installation )
      expect( response.body ).to match(
        %r{<code>client_install_smoke_test</code>.*#{label}\s*<strong>true</strong>}m
      )
    end

    it "shows the installation's variant, matching the endpoint" do
      Flipper.enable( :exp_install_hello_world )
      expected = FeatureFlagging.variant( :install_hello_world, nil, installation_id: installation_id )
      get path, params: { installation_id: installation_id }
      expect( response.body ).to match(
        %r{<code>exp_install_hello_world</code>.*#{label}\s*<strong>#{expected}</strong>}m
      )
    end

    it "says when the id is not a uuid" do
      get path, params: { installation_id: "installation123" }
      expect( response.body ).to include I18n.t( :feature_flags_invalid_installation_id )
      expect( response.body ).not_to include I18n.t( :feature_flags_for_installation )
    end
  end

  it "renders an empty state when no flags exist" do
    Flipper.instance = Flipper.new( Flipper::Adapters::Memory.new )
    get path
    expect( response.body ).to include I18n.t( :feature_flags_none_html, url: flipper_path )
  end
end

# Controller spec: admin_required's throw :abort escapes the integration stack, so it is caught here.
describe Admin::FeatureFlagsController, type: :controller do
  render_views

  it "redirects anonymous visitors" do
    catch( :abort ) { get :index }
    expect( response ).to be_redirect
  end

  it "does not show the flag readout to non-admins" do
    sign_in User.make!
    catch( :abort ) { get :index }
    expect( response ).to be_redirect
    expect( response.body ).not_to include "client_smoke_test"
  end

  it "does not show the flag readout to curators" do
    sign_in make_curator
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
