# frozen_string_literal: true

require "digest"

# Facade over flipper gem enables engine replacement without touching app code.
# Reads fail-closed: keeps pages rendering during deploy→migration window.
#   FeatureFlagging.enabled?( :some_flag, current_user )
#   FeatureFlagging.flags_for( current_user )       # => { client_some_flag: false }
#   FeatureFlagging.variant( :some_experiment, current_user )  # => "treatment"
# Flags are created at runtime in Flipper::UI; the key prefix decides exposure (see kind_of).
module FeatureFlagging
  # client_* flags are sent to browsers and GET /feature_flags; other names stay out of page source.
  CLIENT_PREFIX = "client_"
  # exp_<name> gates enrollment in experiment <name>.
  EXPERIMENT_PREFIX = "exp_"
  # Fixed equal split; changing order or length reshuffles every actor.
  VARIANTS = %w(control treatment).freeze

  # Cache TTL bounds staleness for raw SQL writes or lagging replica reads.
  CACHE_TTL = 10

  # Per process; an unknown key warns once instead of on every check.
  UNKNOWN_KEY_WARNINGS = Concurrent::Map.new

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

    # :client, :experiment, or :server; a bare prefix is server-only.
    def kind_of( key )
      key = key.to_s
      if key.start_with?( CLIENT_PREFIX ) && key.length > CLIENT_PREFIX.length
        :client
      elsif key.start_with?( EXPERIMENT_PREFIX ) && key.length > EXPERIMENT_PREFIX.length
        :experiment
      else
        :server
      end
    end

    def experiment_name( key )
      key.to_s.delete_prefix( EXPERIMENT_PREFIX ).to_sym
    end

    def experiment_flag( experiment )
      :"#{EXPERIMENT_PREFIX}#{experiment}"
    end

    # Every flag that exists in storage, sorted so payloads are byte-stable; memoized per request.
    def feature_keys
      Flipper.features.map( &:key ).sort
    rescue StandardError => e
      Rails.logger.error "[FeatureFlagging] listing features failed, treating as none: #{e.message}"
      []
    end

    # Shown in Flipper::UI so admins can see what a prefix does.
    def description_for( key )
      case kind_of( key )
      when :client
        "Client-visible flag: sent to web and apps as flags.#{key}"
      when :experiment
        name = experiment_name( key )
        "Experiment: enrolls actors into #{name} (#{VARIANTS.join( '/' )}); reported as experiments.#{name}"
      else
        "Server-only flag: read by Rails code only"
      end
    end

    # actor: a User, nil, or anything else responding to #flipper_id
    def enabled?( key, actor = nil )
      key = key.to_sym
      unless exists?( key )
        warn_unknown( key )
        return false
      end

      evaluate( key, resolve_actor( actor ) )
    end

    # Boolean map for inline JS payload and GET /feature_flags.
    def flags_for( actor = nil )
      resolved = resolve_actor( actor )
      client_keys.to_h {| key | [key.to_sym, evaluate( key.to_sym, resolved )] }
    end

    # MD5 bucketing ensures independent experiment assignments; CRC32 linearity fails.
    def variant( experiment, actor = nil )
      experiment = experiment.to_sym
      flag = experiment_flag( experiment )
      unless exists?( flag )
        warn_unknown( flag )
        return nil
      end

      variant_for( experiment, resolve_actor( actor ) )
    end

    # Resolved variant map keyed by experiment name, the documented extension of the flag payload.
    def experiments_for( actor = nil )
      resolved = resolve_actor( actor )
      experiment_keys.to_h do | key |
        name = experiment_name( key )
        [name, variant_for( name, resolved )]
      end
    end

    def reset_unknown_key_warnings
      UNKNOWN_KEY_WARNINGS.clear
    end

    private

    def client_keys
      feature_keys.select {| key | kind_of( key ) == :client }
    end

    def experiment_keys
      feature_keys.select {| key | kind_of( key ) == :experiment }
    end

    def variant_for( experiment, resolved_actor )
      return nil if resolved_actor.nil?
      return nil unless evaluate( experiment_flag( experiment ), resolved_actor )

      VARIANTS[bucket( "#{experiment}:#{resolved_actor.flipper_id}" ) % VARIANTS.size]
    end

    # MD5 bucket stable across releases for analysis.
    def bucket( key )
      Digest::MD5.hexdigest( key )[0, 8].to_i( 16 )
    end

    # Free after preload: the memoizer's get_all also fills the feature list.
    def exists?( key )
      Flipper.exist?( key )
    rescue StandardError => e
      Rails.logger.error "[FeatureFlagging] #{key} existence check failed, treating as off: #{e.message}"
      false
    end

    def warn_unknown( key )
      return unless UNKNOWN_KEY_WARNINGS.put_if_absent( key.to_sym, true ).nil?

      Rails.logger.warn "[FeatureFlagging] unknown feature flag #{key}, treating as off; " \
        "create it at /admin/feature_flags"
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
