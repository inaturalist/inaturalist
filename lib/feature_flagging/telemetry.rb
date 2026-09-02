# frozen_string_literal: true

module FeatureFlagging
  # Per-request flag-read counters, written into the Logstasher request record
  # as the feature_flag_* fields by ApplicationController#append_info_to_payload.
  # WEB-1171 added the memcached layer and preloading on the strength of these
  # numbers; they are how to tell whether either is still earning its keep.
  #
  # Fed by the two flipper notification subscriptions in
  # config/initializers/flipper.rb. CurrentAttributes is reset by the Rails
  # executor around every request, and the executor sits outside
  # Flipper::Middleware::Memoizer, so the preload read is counted too.
  #
  #   feature_flag_checks       FeatureFlagging.enabled? calls ( flipper enabled? operations )
  #   feature_flag_db_reads     reads that reached Postgres
  #   feature_flag_cache_reads  reads that reached memcached ( 0 where there is no cache layer )
  #   feature_flag_runtime      ms spent waiting on storage
  class Telemetry < ActiveSupport::CurrentAttributes
    READ_OPERATIONS = %i[get get_multi get_all features].freeze
    STORAGE = {
      active_record: :db_reads,
      active_support_cache_store: :cache_reads
    }.freeze

    attribute :checks, :db_reads, :cache_reads, :runtime_by_adapter

    def self.record_feature_operation( event )
      return unless event.payload[:operation] == :enabled?

      self.checks = checks.to_i + 1
    end

    def self.record_adapter_operation( event )
      operation, adapter_name = event.payload.values_at( :operation, :adapter_name )
      counter = STORAGE[adapter_name]
      return unless counter && READ_OPERATIONS.include?( operation )

      public_send( "#{counter}=", public_send( counter ).to_i + 1 )
      self.runtime_by_adapter ||= Hash.new( 0.0 )
      runtime_by_adapter[adapter_name] += event.duration
    end

    # Runtime is the time in the outermost storage layer: a cache read wraps
    # the database read it misses to, so the largest per-adapter total is the
    # wall time flipper spent waiting on memcached and/or Postgres.
    def self.payload
      {
        feature_flag_checks: checks.to_i,
        feature_flag_db_reads: db_reads.to_i,
        feature_flag_cache_reads: cache_reads.to_i,
        feature_flag_runtime: ( runtime_by_adapter&.values&.max || 0.0 ).round( 4 )
      }
    end
  end
end
