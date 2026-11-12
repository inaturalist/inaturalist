# frozen_string_literal: true

require "digest"

# Facade over the flipper gem; reads fail closed so pages render during the deploy→migration window.
#   FeatureFlagging.enabled?( :some_flag, current_user )
#   FeatureFlagging.flags_for( current_user )       # => { client_some_flag: false }
#   FeatureFlagging.variant( :some_experiment, current_user )  # => "treatment"
#   FeatureFlagging.flags_for( current_user, installation_id: request.headers["X-Installation-ID"] )
#   FeatureFlagging.enabled?( :some_flag, nil, locale: "fr" )  # locale defaults to I18n.locale
# Flags are created at runtime in Flipper::UI; the key prefix decides exposure (see kind_of)
# and install_ after it buckets by app installation instead of user (see install_scoped?).
module FeatureFlagging
  # client_* flags are exposed through GET /feature_flags; other names stay server-side.
  CLIENT_PREFIX = "client_"
  # exp_<name> gates enrollment in experiment <name>.
  EXPERIMENT_PREFIX = "exp_"
  # client_install_* / exp_install_* bucket by installation, so logging in keeps the assignment.
  INSTALL_MARKER = "install_"
  # Apps send a uuid; anything else is ignored rather than becoming an actor.
  INSTALLATION_ID_PATTERN = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/
  # Fixed equal split; changing order or length reshuffles every actor.
  VARIANTS = %w(control treatment).freeze
  # The gates a request's other identity may still open; percentage gates are left out on purpose.
  TARGETING_GATES = [Flipper::Gates::Actor.new, Flipper::Gates::Group.new].freeze
  # A request with no id can only be matched by a group (e.g. locale_en), never by an actor or percentage.
  ANONYMOUS_GATES = [Flipper::Gates::Group.new].freeze

  # Matches "en" and "en-*" but not "eng".
  ENGLISH_LOCALE = /\Aen(-|\z)/
  # Flipper groups matching the request locale; plain group gates, so they add to other gates.
  # Add a language here to offer it in Flipper UI.
  LOCALE_GROUPS = {
    locale_en: ->( locale ) { ENGLISH_LOCALE.match?( locale ) },
    locale_not_en: ->( locale ) { !ENGLISH_LOCALE.match?( locale ) }
  }.freeze

  # Cache TTL bounds staleness for raw SQL writes or lagging replica reads.
  CACHE_TTL = 10

  # Per process; an unknown key warns once instead of on every check.
  UNKNOWN_KEY_WARNINGS = Concurrent::Map.new

  class << self
    def build_adapter( base: Flipper::Adapters::ActiveRecord.new, cache: shared_cache, ttl: CACHE_TTL )
      adapter = base
      if cache
        adapter = Flipper::Adapters::ActiveSupportCacheStore.new( adapter, cache, ttl, prefix: "#{Rails.env}:" )
      end
      FeatureFlagging::FailClosedAdapter.new( adapter )
    end

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

    # True for client_install_<name> and exp_install_<name>; case-sensitive like kind_of.
    def install_scoped?( key )
      prefix = { client: CLIENT_PREFIX, experiment: EXPERIMENT_PREFIX }[kind_of( key )]
      return false unless prefix

      rest = key.to_s.delete_prefix( prefix )
      rest.start_with?( INSTALL_MARKER ) && rest.length > INSTALL_MARKER.length
    end

    def valid_installation_id?( installation_id )
      installation_id.is_a?( String ) && INSTALLATION_ID_PATTERN.match?( installation_id )
    end

    def locale_in_group?( group, locale )
      matcher = LOCALE_GROUPS[group.to_sym]
      locale = locale.to_s
      return false if matcher.nil? || locale.blank?

      matcher.call( locale )
    end

    # Called after boot from config/initializers/flipper.rb; group blocks receive a RequestActor.
    def register_locale_groups
      LOCALE_GROUPS.each_key do | group |
        next if Flipper.group_exists?( group )

        Flipper.register( group ) do | actor |
          actor.respond_to?( :locale ) && locale_in_group?( group, actor.locale )
        end
      end
    end

    def experiment_name( key )
      key.to_s.delete_prefix( EXPERIMENT_PREFIX ).to_sym
    end

    def experiment_flag( experiment )
      :"#{EXPERIMENT_PREFIX}#{experiment}"
    end

    # Every stored flag key, sorted so payloads are byte-stable.
    def feature_keys
      Flipper.features.map( &:key ).sort
    rescue StandardError => e
      Rails.logger.error "[FeatureFlagging] listing features failed, treating as none: #{e.message}"
      []
    end

    # Shown in Flipper::UI so admins can see what a prefix does.
    def description_for( key )
      description = case kind_of( key )
      when :client
        "Client-visible flag: sent to web and apps as flags.#{key}"
      when :experiment
        name = experiment_name( key )
        "Experiment: enrolls actors into #{name} (#{VARIANTS.join( '/' )}); reported as experiments.#{name}"
      else
        "Server-only flag: read by Rails code only"
      end
      install_scoped?( key ) ? "#{description}; buckets by app installation, logged out or in" : description
    end

    # actor: a User, nil, or anything else responding to #flipper_id
    # installation_id: the app's X-Installation-ID; only install_ flags use it
    # locale: matched by the locale_ groups; the app's language on GET /feature_flags
    def enabled?( key, actor = nil, installation_id: nil, locale: I18n.locale )
      key = key.to_sym
      unless exists?( key )
        warn_unknown( key )
        return false
      end

      evaluate( key, resolve_request( actor, installation_id, locale ) )
    end

    # Client flag map for GET /feature_flags.
    def flags_for( actor = nil, installation_id: nil, locale: I18n.locale )
      request = resolve_request( actor, installation_id, locale )
      client_keys.to_h {| key | [key.to_sym, evaluate( key.to_sym, request )] }
    end

    # MD5 bucketing ensures independent experiment assignments; CRC32 linearity fails.
    def variant( experiment, actor = nil, installation_id: nil, locale: I18n.locale )
      experiment = experiment.to_sym
      flag = experiment_flag( experiment )
      unless exists?( flag )
        warn_unknown( flag )
        return nil
      end

      variant_for( experiment, resolve_request( actor, installation_id, locale ) )
    end

    # Variant map keyed by experiment name for GET /feature_flags.
    def experiments_for( actor = nil, installation_id: nil, locale: I18n.locale )
      request = resolve_request( actor, installation_id, locale )
      experiment_keys.to_h do | key |
        name = experiment_name( key )
        [name, variant_for( name, request )]
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

    def variant_for( experiment, request )
      flag = experiment_flag( experiment )
      actor = actor_for_key( flag, request )
      return nil if actor.nil?
      return nil unless evaluate( flag, request )

      VARIANTS[bucket( "#{experiment}:#{actor.flipper_id}" ) % VARIANTS.size]
    end

    # MD5 bucket stable across releases for analysis.
    def bucket( key )
      Digest::MD5.hexdigest( key )[0, 8].to_i( 16 )
    end

    def exists?( key )
      Flipper.exist?( key )
    rescue StandardError => e
      Rails.logger.error "[FeatureFlagging] #{key} existence check failed, treating as off: #{e.message}"
      false
    end

    def warn_unknown( key )
      return unless UNKNOWN_KEY_WARNINGS.put_if_absent( key.to_sym, true ).nil?

      Rails.logger.warn "[FeatureFlagging] unknown feature flag #{key}, treating as off; " \
        "create it at /admin/feature_flags/flipper"
    end

    def evaluate( key, request )
      actor = actor_for_key( key, request )
      return true if actor ? Flipper.enabled?( key, actor ) : Flipper.enabled?( key )

      targeted?( key, request )
    rescue StandardError => e
      Rails.logger.error "[FeatureFlagging] #{key} evaluation failed, treating as off: #{e.message}"
      false
    end

    # Flipper saw only the bucketing id. An actor or group gate may still name the request's other
    # identity, so run just those two over both; passing both to Flipper would re-roll percentages at login.
    # With no identity, only groups run, over the id-less request, so locale_ groups reach logged-out visitors.
    def targeted?( key, request )
      identities = request.identities
      gates = TARGETING_GATES
      if identities.empty?
        identities = [request]
        gates = ANONYMOUS_GATES
      end

      context = Flipper::FeatureCheckContext.new(
        feature_name: key,
        values: Flipper[key].gate_values,
        actors: identities.map {| identity | Flipper::Types::Actor.wrap( identity ) }
      )
      gates.any? {| gate | gate.open?( context ) }
    end

    def resolve_request( actor, installation_id, locale )
      installation_id = nil unless valid_installation_id?( installation_id )
      FeatureFlagging::RequestActor.new( resolve_actor( actor ), installation_id, locale: locale )
    end

    def actor_for_key( key, request )
      request.bucketed_by( install_scoped?( key ) ? :installation : :user )
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
