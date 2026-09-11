# frozen_string_literal: true

require "spec_helper"

# Preload runs before controller code, outside evaluate's rescue; these specs pin safety.
describe "flipper preloading", type: :request do
  include Devise::Test::IntegrationHelpers

  let( :flag ) { :client_smoke_test }

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

    it "renders a page with an empty flag map instead of a 500" do
      get "/observations"
      expect( response.response_code ).to eq 200
      expect( response.body ).to include "feature_flags: {}"
    end

    it "serves the flag endpoint with empty maps" do
      get "/feature_flags"
      expect( response.response_code ).to eq 200
      expect( JSON.parse( response.body ) ).to eq( "flags" => {}, "experiments" => {} )
    end

    it "logs the preload failure" do
      get "/feature_flags"
      expect( Rails.logger ).to have_received( :error ).with( /\[FeatureFlagging\] adapter get_all failed/ )
    end
  end

  describe "read volume" do
    let( :base ) { counting_adapter }

    before { install( base: base ) }

    # The preloaded feature set doubles as the registry, so existence checks are free too.
    it "preloads every created flag in one read" do
      add_test_flags
      Flipper.add( :client_demo_banner )
      get "/observations"
      expect( base.count( :get_all ) ).to eq 1
      expect( base.count( :get ) ).to eq 0
      expect( base.count( :features ) ).to eq 0
    end

    it "does not read gates for a flag that was never created" do
      allow( Rails.logger ).to receive( :warn )
      get "/observations"
      expect( base.count( :get_all ) ).to eq 1
      expect( base.count( :get ) ).to eq 0
    end
  end

  describe "through a shared cache" do
    let( :actor ) { User.make! }

    before do
      install( base: Flipper::Adapters::ActiveRecord.new, cache: ActiveSupport::Cache::MemoryStore.new )
      Flipper.add( flag )
    end

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
