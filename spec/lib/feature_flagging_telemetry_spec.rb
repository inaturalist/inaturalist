# frozen_string_literal: true

require "spec_helper"

describe FeatureFlagging::Telemetry do
  let( :flag ) { :client_smoke_test }
  let( :actor ) { User.make! }

  def install( base:, cache: nil, memoize: true )
    Flipper.instance = Flipper.new(
      FeatureFlagging.build_adapter( base: base, cache: cache ),
      instrumenter: ActiveSupport::Notifications,
      memoize: memoize
    )
  end

  before { described_class.reset }

  it "reports zeros when nothing was read" do
    expect( described_class.payload ).to eq(
      feature_flag_checks: 0,
      feature_flag_db_reads: 0,
      feature_flag_cache_reads: 0,
      feature_flag_runtime: 0.0
    )
  end

  describe "checks" do
    before { Flipper.add( flag ) }

    it "counts enabled? checks" do
      3.times { FeatureFlagging.enabled?( flag, actor ) }
      expect( described_class.payload[:feature_flag_checks] ).to eq 3
    end

    it "ignores other feature operations" do
      Flipper.enable( flag )
      Flipper.disable( flag )
      expect( described_class.payload[:feature_flag_checks] ).to eq 0
    end
  end

  describe "reads" do
    # Unmemoized, each check is a feature-list read plus a gate read.
    it "counts reads that reach the database" do
      install( base: Flipper::Adapters::ActiveRecord.new, memoize: false )
      Flipper.add( flag )
      2.times { FeatureFlagging.enabled?( flag, actor ) }
      expect( described_class.payload ).to include( feature_flag_db_reads: 4, feature_flag_cache_reads: 0 )
    end

    it "counts only the feature list read for a flag that does not exist" do
      allow( Rails.logger ).to receive( :warn )
      install( base: Flipper::Adapters::ActiveRecord.new, memoize: false )
      FeatureFlagging.enabled?( :not_a_real_flag, actor )
      expect( described_class.payload ).to include( feature_flag_checks: 0, feature_flag_db_reads: 1 )
    end

    it "counts cache reads separately from the database reads they miss to" do
      install(
        base: Flipper::Adapters::ActiveRecord.new,
        cache: ActiveSupport::Cache::MemoryStore.new,
        memoize: false
      )
      Flipper.add( flag )
      2.times { FeatureFlagging.enabled?( flag, actor ) }
      expect( described_class.payload ).to include( feature_flag_db_reads: 2, feature_flag_cache_reads: 4 )
    end

    it "does not count writes" do
      install( base: Flipper::Adapters::ActiveRecord.new )
      Flipper.enable( flag )
      expect( described_class.payload ).to include( feature_flag_db_reads: 0, feature_flag_cache_reads: 0 )
    end

    it "records the time spent in storage in milliseconds" do
      install( base: Flipper::Adapters::ActiveRecord.new )
      Flipper.add( flag )
      FeatureFlagging.enabled?( flag, actor )
      expect( described_class.payload[:feature_flag_runtime] ).to be > 0
    end
  end

  describe "in a request", type: :request do
    let( :payloads ) { [] }

    before do
      install( base: Flipper::Adapters::ActiveRecord.new )
      add_test_flags
      Flipper.add( :client_demo_banner )
      @subscription = ActiveSupport::Notifications.subscribe( "process_action.action_controller" ) do | event |
        payloads << event.payload
      end
    end

    after { ActiveSupport::Notifications.unsubscribe( @subscription ) }

    it "adds the counters to the request payload Logstasher writes" do
      get "/observations"
      expect( payloads.last ).to include( feature_flag_db_reads: 1, feature_flag_cache_reads: 0 )
      expect( payloads.last[:feature_flag_checks] ).to be >= 2
      expect( payloads.last[:feature_flag_runtime] ).to be > 0
    end

    it "resets between requests" do
      get "/observations"
      first = payloads.last.slice( :feature_flag_checks, :feature_flag_db_reads )
      get "/observations"
      expect( payloads.last.slice( :feature_flag_checks, :feature_flag_db_reads ) ).to eq first
    end
  end
end
