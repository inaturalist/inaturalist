# frozen_string_literal: true

require "spec_helper"

describe "flipper initializer" do
  let( :flipper_config ) { Rails.application.config.flipper }

  it "builds the storage stack with FeatureFlagging.build_adapter" do
    adapter = Flipper.configuration.adapter
    expect( adapter ).to be_a Flipper::Adapters::ActorLimit
    expect( adapter.adapter ).to be_a FeatureFlagging::FailClosedAdapter
  end

  it "memoizes and preloads per request" do
    expect( flipper_config.memoize ).to be true
    expect( flipper_config.preload ).to be true
  end

  it "runs the memoizer innermost, inside Makara" do
    klasses = Rails.application.middleware.map( &:klass )
    expect( klasses.last ).to eq Flipper::Middleware::Memoizer
    expect( klasses.index( Makara::Middleware ) ).to be < klasses.index( Flipper::Middleware::Memoizer )
  end

  it "adds no cache layer for the test cache store" do
    expect( FeatureFlagging.shared_cache ).to be_nil
  end

  it "feeds flag checks into the telemetry" do
    expect( FeatureFlagging::Telemetry ).to receive( :record_feature_operation )
    Flipper.enabled?( :flipper_smoke_test )
  end

  it "feeds storage reads into the telemetry" do
    expect( FeatureFlagging::Telemetry ).to receive( :record_adapter_operation )
    Flipper.new( FeatureFlagging.build_adapter( base: Flipper::Adapters::Memory.new, cache: nil ) ).
      enabled?( :flipper_smoke_test )
  end
end
