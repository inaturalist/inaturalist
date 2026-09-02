# frozen_string_literal: true

require "spec_helper"

# Preloading runs in Flipper::Middleware::Memoizer, before any controller code,
# so it is the one flag read that FeatureFlagging.evaluate's rescue cannot
# protect. These specs pin what makes it safe to leave on.
describe "flipper preloading", type: :request do
  include Devise::Test::IntegrationHelpers

  let( :flag ) { :flipper_smoke_test }

  def install( base:, cache: nil )
    Flipper.instance = Flipper.new(
      FeatureFlagging.build_adapter( base: base, cache: cache ),
      instrumenter: ActiveSupport::Notifications
    )
  end

  describe "when storage raises" do
    before do
      allow( Rails.logger ).to receive( :error )
      install( base: raising_adapter )
    end

    it "renders a page with every flag off instead of a 500" do
      get "/observations"
      expect( response.response_code ).to eq 200
      expect( response.body ).to include( "\"#{flag}\":false" )
    end

    it "serves the flag endpoint with everything off" do
      get "/feature_flags"
      expect( response.response_code ).to eq 200
      expect( JSON.parse( response.body )["flags"].values ).to all( be false )
    end

    it "logs the preload failure" do
      get "/feature_flags"
      expect( Rails.logger ).to have_received( :error ).with( /\[FeatureFlagging\] adapter get_all failed/ )
    end
  end

  describe "read volume" do
    let( :base ) { counting_adapter }

    before { install( base: base ) }

    it "preloads every registered flag in one read" do
      register_known_flags
      get "/observations"
      expect( base.count( :get_all ) ).to eq 1
      expect( base.count( :get ) ).to eq 0
    end

    # Preload only covers rows in flipper_features, so a declared flag nobody
    # has registered still costs a read of its own. Keep KNOWN_FLAGS registered.
    it "reads an unregistered flag once per request" do
      ( FeatureFlagging::KNOWN_FLAGS.keys - [flag] ).each {| key | Flipper.add( key ) }
      get "/observations"
      expect( base.count( :get_all ) ).to eq 1
      expect( base.count( :get ) ).to eq 1
    end
  end

  describe "through a shared cache" do
    let( :actor ) { User.make! }

    before { install( base: Flipper::Adapters::ActiveRecord.new, cache: ActiveSupport::Cache::MemoryStore.new ) }

    it "sees a toggle on the very next request" do
      sign_in actor
      get "/feature_flags"
      expect( JSON.parse( response.body )["flags"][flag.to_s] ).to be false
      Flipper.enable_actor( flag, actor )
      get "/feature_flags"
      expect( JSON.parse( response.body )["flags"][flag.to_s] ).to be true
    end
  end
end
