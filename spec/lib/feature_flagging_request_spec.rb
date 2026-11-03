# frozen_string_literal: true

require "spec_helper"

# Memoize on, preload off: a request pays only for the flags it reads, once each.
describe "flag reads during a request", type: :request do
  include Devise::Test::IntegrationHelpers

  let( :flag ) { :client_smoke_test }

  def install( base:, cache: nil )
    Flipper.instance = Flipper.new( FeatureFlagging.build_adapter( base: base, cache: cache ) )
  end

  describe "a page that reads no flag" do
    it "does no flag storage work at all" do
      base = counting_adapter
      install( base: base )
      add_test_flags
      base.reset
      get "/observations"
      expect( response.response_code ).to eq 200
      expect( base.count ).to eq 0
    end

    it "renders when storage raises" do
      allow( Rails.logger ).to receive( :error )
      install( base: raising_adapter )
      get "/observations"
      expect( response.response_code ).to eq 200
    end
  end

  describe "GET /feature_flags" do
    let( :base ) { counting_adapter }

    before do
      install( base: base )
      add_test_flags
      sign_in User.make!
      base.reset
    end

    # flags_for and experiments_for both list features; the Memoizer middleware dedupes the read.
    it "reads the feature list once per request, not once per map" do
      get "/feature_flags"
      expect( base.count( :features ) ).to eq 1
    end

    it "reads gates once for each exposed flag and never preloads" do
      get "/feature_flags"
      expect( base.count( :get ) ).to eq 2
      expect( base.count( :get_all ) ).to eq 0
      expect( base.count( :get_multi ) ).to eq 0
    end

    it "does not read gates for a server-only flag" do
      get "/feature_flags"
      read_keys = base.type( :get ).map {| operation | operation.args.first.key }
      expect( read_keys ).to match_array %w(client_smoke_test exp_hello_world)
    end

    # Anonymous callers are never enrolled, so experiment gates are not worth a read.
    it "skips experiment gates for an anonymous caller" do
      sign_out :user
      get "/feature_flags"
      read_keys = base.type( :get ).map {| operation | operation.args.first.key }
      expect( read_keys ).to eq %w(client_smoke_test)
    end

    describe "with an installation id" do
      let( :headers ) { { "HTTP_X_INSTALLATION_ID" => SecureRandom.uuid } }

      before do
        add_install_test_flags
        base.reset
      end

      it "reads installation experiment gates but not user ones when logged out" do
        sign_out :user
        get "/feature_flags", headers: headers
        read_keys = base.type( :get ).map {| operation | operation.args.first.key }
        expect( read_keys ).to match_array %w(client_install_smoke_test client_smoke_test exp_install_hello_world)
      end

      # The signed-in user's actor gate check reuses the memoized gate values.
      it "still reads each gate once when signed in" do
        get "/feature_flags", headers: headers
        expect( base.count( :get ) ).to eq 4
      end
    end
  end

  describe "GET /feature_flags when no flag exists" do
    let( :base ) { counting_adapter }

    before { install( base: base ) }

    it "reads only the feature list" do
      get "/feature_flags"
      expect( base.count( :features ) ).to eq 1
      expect( base.count( :get ) ).to eq 0
    end
  end

  describe "when storage raises" do
    before do
      allow( Rails.logger ).to receive( :error )
      install( base: raising_adapter )
    end

    it "serves the flag endpoint with empty maps" do
      get "/feature_flags"
      expect( response.response_code ).to eq 200
      expect( JSON.parse( response.body ) ).to eq( "flags" => {}, "experiments" => {} )
    end

    it "logs the failed read" do
      get "/feature_flags"
      expect( Rails.logger ).to have_received( :error ).with( /\[FeatureFlagging\] adapter features failed/ )
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
