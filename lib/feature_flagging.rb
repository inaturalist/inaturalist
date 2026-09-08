# frozen_string_literal: true

require "digest"

# Facade over flipper gem enables engine replacement without touching app code.
# Reads fail-closed: keeps pages rendering during deploy→migration window.
#   FeatureFlagging.enabled?( :some_flag, current_user )
#   FeatureFlagging.flags_for( current_user )       # => { some_flag: false }
#   FeatureFlagging.variant( :some_experiment, current_user )  # => "treatment"
# Only CLIENT_FLAGS sent to browsers; server doesn't read client targeting rules.
module FeatureFlagging
  # Registry of known flags; unlisted keys raise to prevent silent failures.
  KNOWN_FLAGS = {
    flipper_smoke_test: "WEB-1074 pilot flag. Gates nothing; proves the flag pipeline end to end.",
    exp_hello_world: "WEB-1074 pilot experiment. Gates eligibility for the hello_world variant split.",
    demo_banner: "WEB-1074 demo. Shows a badge in the site footer and a banner on observation " \
      "pages, so one toggle is visible through both the server-rendered and the client-side " \
      "path. Enable for named actors only; delete with the demo elements once a real flag ships."
  }.freeze

  # Subset sent to browsers; keeps unannounced feature names from page source.
  CLIENT_FLAGS = [
    :flipper_smoke_test,
    :demo_banner
  ].freeze

  # Experiments with variant assignment per eligible actor; deterministic (no table).
  KNOWN_EXPERIMENTS = {
    hello_world: %w(control treatment)
  }.freeze

  # Cache TTL bounds staleness for raw SQL writes or lagging replica reads.
  CACHE_TTL = 10

  class UnknownFlagError < StandardError; end
  class UnknownExperimentError < StandardError; end

  class << self
    # Stack: fail_closed → instrumented → [cache →] instrumented → base; failures = all-flags-off.
    def build_adapter( base: Flipper::Adapters::ActiveRecord.new, cache: shared_cache, ttl: CACHE_TTL )
      adapter = Flipper::Adapters::Instrumented.new( base, instrumenter: ActiveSupport::Notifications )
      if cache
        # Prefix keeps environments sharing memcached separate.
        adapter = Flipper::Adapters::ActiveSupportCacheStore.new( adapter, cache, ttl, prefix: "#{Rails.env}:" )
        adapter = Flipper::Adapters::Instrumented.new( adapter, instrumenter: ActiveSupport::Notifications )
      end
      # Fully qualified: bare constant in `class << self` not resolved by classic autoloader.
      FeatureFlagging::FailClosedAdapter.new( adapter )
    end

    # Only memcached is shared; file/memory stores per-process, not faster than one indexed read.
    def shared_cache( store = Rails.cache )
      store if store.is_a?( ActiveSupport::Cache::MemCacheStore )
    end

    # actor: a User, nil, or anything else responding to #flipper_id
    def enabled?( key, actor = nil )
      key = key.to_sym
      raise UnknownFlagError, "unknown feature flag: #{key}" unless KNOWN_FLAGS.key?( key )

      evaluate( key, resolve_actor( actor ) )
    end

    # Boolean map for inline JS payload and GET /v2/feature_flags endpoint.
    def flags_for( actor = nil )
      resolved = resolve_actor( actor )
      CLIENT_FLAGS.index_with {| key | evaluate( key, resolved ) }
    end

    # MD5 bucketing ensures independent experiment assignments; CRC32 linearity fails.
    def variant( experiment, actor = nil )
      experiment = experiment.to_sym
      variants = KNOWN_EXPERIMENTS[experiment]
      raise UnknownExperimentError, "unknown experiment: #{experiment}" if variants.blank?

      resolved = resolve_actor( actor )
      return nil if resolved.nil?
      return nil unless evaluate( experiment_flag( experiment ), resolved )

      variants[bucket( "#{experiment}:#{resolved.flipper_id}" ) % variants.size]
    end

    # Resolved variant map, the documented extension of the flag payload.
    def experiments_for( actor = nil )
      KNOWN_EXPERIMENTS.keys.index_with {| experiment | variant( experiment, actor ) }
    end

    # The flag that gates eligibility for an experiment.
    def experiment_flag( experiment )
      :"exp_#{experiment}"
    end

    private

    # MD5 bucket stable across releases for analysis.
    def bucket( key )
      Digest::MD5.hexdigest( key )[0, 8].to_i( 16 )
    end

    def evaluate( key, resolved_actor )
      if resolved_actor
        Flipper.enabled?( key, resolved_actor )
      else
        Flipper.enabled?( key )
      end
    rescue StandardError => e
      Rails.logger.error "[FeatureFlagging] #{key} evaluation failed, treating as off: #{e.message}"
      false
    end

    # Logged-out mobile shares User(id: -1); guard prevents percentage gates misfire.
    def resolve_actor( actor )
      return nil if actor.blank?
      return nil if actor.respond_to?( :anonymous? ) && actor.anonymous?
      return actor if actor.respond_to?( :flipper_id )

      raise ArgumentError, "feature flag actor must respond to #flipper_id, got #{actor.class}"
    end
  end
end
