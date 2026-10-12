# frozen_string_literal: true

require "spec_helper"

describe "flipper initializer" do
  let( :flipper_config ) { Rails.application.config.flipper }

  it "builds the storage stack with FeatureFlagging.build_adapter" do
    adapter = Flipper.configuration.adapter
    expect( adapter ).to be_a Flipper::Adapters::ActorLimit
    expect( adapter.adapter ).to be_a FeatureFlagging::FailClosedAdapter
  end

  it "memoizes per request without preloading" do
    expect( flipper_config.memoize ).to be true
    expect( flipper_config.preload ).to be false
  end

  it "runs the memoizer innermost, inside Makara" do
    klasses = Rails.application.middleware.map( &:klass )
    expect( klasses.last ).to eq Flipper::Middleware::Memoizer
    expect( klasses.index( Makara::Middleware ) ).to be < klasses.index( Flipper::Middleware::Memoizer )
  end

  it "describes flags in the UI from their key prefix" do
    ui = Flipper::UI.configuration
    expect( ui.show_feature_description_in_list ).to be true
    expect( ui.descriptions_source.call( %w(client_a exp_b c) ).values.uniq.size ).to eq 3
  end

  it "adds no cache layer for the test cache store" do
    expect( FeatureFlagging.shared_cache ).to be_nil
  end
end
