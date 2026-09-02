# frozen_string_literal: true

require "flipper/adapters/operation_logger"

# Stand-ins for the storage behind FeatureFlagging.build_adapter, shared by the
# feature_flagging_*_spec files.
module FeatureFlaggingHelpers
  # Every operation raises the way ActiveRecord does when the flipper tables
  # have not been migrated yet.
  class RaisingAdapter
    include Flipper::Adapter

    Flipper::Adapters::Wrapper::METHODS.each do | method |
      define_method( method ) do | *_args, **_kwargs |
        raise ActiveRecord::StatementInvalid,
          "PG::UndefinedTable: ERROR:  relation \"flipper_features\" does not exist"
      end
    end
  end

  # A cache store whose reads blow up, for "the cache layer itself is broken".
  class ExplodingCacheStore < ActiveSupport::Cache::MemoryStore
    def fetch( *_args, **_kwargs )
      raise IOError, "cache exploded"
    end

    def read_multi( *_args, **_kwargs )
      raise IOError, "cache exploded"
    end
  end

  def raising_adapter
    RaisingAdapter.new
  end

  # In-memory storage that counts what reaches it: `counting.count( :get_all )`
  def counting_adapter
    Flipper::Adapters::OperationLogger.new( Flipper::Adapters::Memory.new )
  end

  # Registers every declared flag so a preload covers all of them
  def register_known_flags( flipper = Flipper )
    FeatureFlagging::KNOWN_FLAGS.each_key {| key | flipper.add( key ) }
  end
end

RSpec.configure do | config |
  config.include FeatureFlaggingHelpers
end
