# frozen_string_literal: true

module FeatureFlagging
  # Per-request flag-read counters written into Logstasher. Preload counted because executor outside Memoizer.
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

    # Runtime: wall time in outermost storage layer (cache wraps base).
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
