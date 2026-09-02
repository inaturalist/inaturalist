# frozen_string_literal: true

require "spec_helper"

describe "FeatureFlagging.build_adapter" do
  include ActiveSupport::Testing::TimeHelpers

  let( :flag ) { :flipper_smoke_test }
  let( :base ) { counting_adapter }
  let( :cache ) { ActiveSupport::Cache::MemoryStore.new }

  # Non-memoizing, so every read reaches the stack the way one read per request
  # would in production.
  def flipper_over( adapter )
    Flipper.new( adapter, memoize: false )
  end

  it "is fail-closed outermost" do
    expect( FeatureFlagging.build_adapter( base: base, cache: nil ) ).
      to be_a FeatureFlagging::FailClosedAdapter
  end

  it "instruments reads of the base adapter" do
    events = []
    subscription = ActiveSupport::Notifications.subscribe( "adapter_operation.flipper" ) do | event |
      events << event
    end
    flipper_over( FeatureFlagging.build_adapter( base: Flipper::Adapters::Memory.new, cache: nil ) ).
      enabled?( flag )
    ActiveSupport::Notifications.unsubscribe( subscription )
    expect( events.map {| e | e.payload.values_at( :operation, :adapter_name ) } ).to eq [[:get, :memory]]
  end

  it "adds no cache layer without a cache" do
    flipper = flipper_over( FeatureFlagging.build_adapter( base: base, cache: nil ) )
    2.times { flipper.enabled?( flag ) }
    expect( base.count( :get ) ).to eq 2
  end

  it "reads through the cache when given one" do
    flipper = flipper_over( FeatureFlagging.build_adapter( base: base, cache: cache ) )
    2.times { flipper.enabled?( flag ) }
    expect( base.count( :get ) ).to eq 1
  end

  it "keeps cached gates for CACHE_TTL seconds" do
    expect( FeatureFlagging::CACHE_TTL ).to eq 10
    flipper_over( FeatureFlagging.build_adapter( base: base, cache: cache ) ).enabled?( flag )
    key = "test:flipper/v1/feature/#{flag}"
    travel( FeatureFlagging::CACHE_TTL - 1 ) { expect( cache.exist?( key ) ).to be true }
    travel( FeatureFlagging::CACHE_TTL + 1 ) { expect( cache.exist?( key ) ).to be false }
  end

  it "prefixes cache keys with the environment" do
    flipper_over( FeatureFlagging.build_adapter( base: base, cache: cache ) ).enabled?( flag )
    expect( cache.exist?( "test:flipper/v1/feature/#{flag}" ) ).to be true
  end

  it "serves reads from the cache until the entry expires" do
    flipper = flipper_over( FeatureFlagging.build_adapter( base: base, cache: cache ) )
    expect( flipper.enabled?( flag ) ).to be false
    # A write that bypasses the stack ( raw SQL in production ) stays invisible
    # until the cached entry expires
    Flipper.new( base ).enable( flag )
    expect( flipper.enabled?( flag ) ).to be false
    cache.clear
    expect( flipper.enabled?( flag ) ).to be true
  end

  it "expires the cache on writes so a toggle is visible on the next read" do
    flipper = flipper_over( FeatureFlagging.build_adapter( base: base, cache: cache ) )
    expect( flipper.enabled?( flag ) ).to be false
    flipper.enable( flag )
    expect( flipper.enabled?( flag ) ).to be true
    flipper.disable( flag )
    expect( flipper.enabled?( flag ) ).to be false
  end

  it "still fails closed when the cache layer raises" do
    allow( Rails.logger ).to receive( :error )
    Flipper.new( base ).enable( flag )
    exploding = FeatureFlaggingHelpers::ExplodingCacheStore.new
    flipper = flipper_over( FeatureFlagging.build_adapter( base: base, cache: exploding ) )
    expect( flipper.enabled?( flag ) ).to be false
    expect( Rails.logger ).to have_received( :error ).
      with( /\[FeatureFlagging\] adapter get failed.*IOError: cache exploded/ )
  end

  describe "defaults" do
    it "stores flags in ActiveRecord" do
      expect( Flipper::Adapters::ActiveRecord ).to receive( :new ).and_call_original
      FeatureFlagging.build_adapter
    end

    it "caches in the shared cache" do
      allow( FeatureFlagging ).to receive( :shared_cache ).and_return( cache )
      flipper_over( FeatureFlagging.build_adapter( base: base ) ).enabled?( flag )
      expect( cache.exist?( "test:flipper/v1/feature/#{flag}" ) ).to be true
    end
  end
end

describe "FeatureFlagging.shared_cache" do
  it "returns a memcached store" do
    # Dalli connects lazily, so no memcached is needed to construct this
    store = ActiveSupport::Cache::MemCacheStore.new( "localhost" )
    expect( FeatureFlagging.shared_cache( store ) ).to eq store
  end

  it "returns nil for a memory store" do
    expect( FeatureFlagging.shared_cache( ActiveSupport::Cache::MemoryStore.new ) ).to be_nil
  end

  it "returns nil for a file store" do
    expect( FeatureFlagging.shared_cache( ActiveSupport::Cache::FileStore.new( Dir.tmpdir ) ) ).to be_nil
  end

  it "returns nil for the test cache store" do
    expect( FeatureFlagging.shared_cache ).to be_nil
  end
end
