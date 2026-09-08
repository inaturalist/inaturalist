# frozen_string_literal: true

require "flipper/adapters/operation_logger"

# Test doubles for the storage stack, shared by feature_flagging_*_spec files.
module FeatureFlaggingHelpers
  # All operations raise like unmigrated tables.
  class RaisingAdapter
    include Flipper::Adapter

    Flipper::Adapters::Wrapper::METHODS.each do | method |
      define_method( method ) do | *_args, **_kwargs |
        raise ActiveRecord::StatementInvalid,
          "PG::UndefinedTable: ERROR:  relation \"flipper_features\" does not exist"
      end
    end
  end

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

  def counting_adapter
    Flipper::Adapters::OperationLogger.new( Flipper::Adapters::Memory.new )
  end

  def register_known_flags( flipper = Flipper )
    FeatureFlagging::KNOWN_FLAGS.each_key {| key | flipper.add( key ) }
  end
end

RSpec.configure do | config |
  config.include FeatureFlaggingHelpers
end
