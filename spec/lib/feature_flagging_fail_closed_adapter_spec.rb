# frozen_string_literal: true

require "spec_helper"

describe FeatureFlagging::FailClosedAdapter do
  let( :flag ) { :flipper_smoke_test }
  let( :memory ) { Flipper::Adapters::Memory.new }
  let( :feature ) { Flipper::Feature.new( flag, memory ) }

  describe "when storage works" do
    let( :flipper ) { Flipper.new( described_class.new( memory ) ) }

    it "delegates reads and writes" do
      expect( flipper.enabled?( flag ) ).to be false
      flipper.enable( flag )
      expect( flipper.enabled?( flag ) ).to be true
      expect( flipper.features.map( &:key ) ).to eq [flag.to_s]
    end
  end

  describe "when a read raises" do
    let( :adapter ) { described_class.new( raising_adapter ) }

    before { allow( Rails.logger ).to receive( :error ) }

    it "returns an empty Set from features" do
      expect( adapter.features ).to eq Set.new
    end

    it "returns an empty Hash from get, get_multi and get_all" do
      expect( adapter.get( feature ) ).to eq( {} )
      expect( adapter.get_multi( [feature] ) ).to eq( {} )
      expect( adapter.get_all ).to eq( {} )
    end

    it "logs each failed read with the FeatureFlagging prefix and the cause" do
      adapter.get_all
      expect( Rails.logger ).to have_received( :error ).
        with( /\[FeatureFlagging\] adapter get_all failed.*StatementInvalid.*flipper_features/ )
    end

    it "makes every flag report off end to end" do
      expect( Flipper.new( adapter ).enabled?( flag ) ).to be false
    end

    it "makes preload_all return no features instead of raising" do
      expect( Flipper.new( adapter ).preload_all ).to eq []
    end
  end

  describe "when a write raises" do
    let( :adapter ) { described_class.new( raising_adapter ) }
    let( :flipper ) { Flipper.new( adapter ) }

    # An admin toggling a flag while storage is broken should see the error,
    # not a success page for a change that never happened.
    it "re-raises from enable, disable, add and remove" do
      expect { flipper.enable( flag ) }.to raise_error ActiveRecord::StatementInvalid
      expect { flipper.disable( flag ) }.to raise_error ActiveRecord::StatementInvalid
      expect { flipper.add( flag ) }.to raise_error ActiveRecord::StatementInvalid
      expect { flipper.remove( flag ) }.to raise_error ActiveRecord::StatementInvalid
    end

    it "re-raises from clear" do
      expect { adapter.clear( feature ) }.to raise_error ActiveRecord::StatementInvalid
    end
  end
end
