module MakaraLoggingSubscriber
  # extending this method to not return a wrapper name for cached queries.
  # This will fix a bug in query logging which was improperly reporting
  # that all cached queries were being run against the primary, not cached
  def current_wrapper_name(event)
    return nil if event.payload[:cached]
    super(event)
  end
end

# apply the above fix for cached query logging
ActiveRecord::LogSubscriber.log_subscribers.each do |subscriber|
  subscriber.extend ::MakaraLoggingSubscriber
end

# fix for makara DB name logging for Rails 6
module Makara
  module Logging
    module Subscriber
      protected

      # overriding this method to properly fetch the adapter for Rails 6
      def current_wrapper_name(event)
        adapter = event.payload[:connection]

        return nil unless adapter
        return nil unless adapter.respond_to?(:_makara_name)

        "[#{adapter._makara_name}]"
      end
    end
  end
end

# ensure MakaraAbstractAdapter is defined even for environments not using makara
module ActiveRecord
  module ConnectionAdapters
    class MakaraAbstractAdapter < ::Makara::Proxy

      SQL_PRIMARY_MATCHERS = [] unless defined?( SQL_PRIMARY_MATCHERS )
      CUSTOM_SQL_PRIMARY_MATCHERS = SQL_PRIMARY_MATCHERS +
        [/delayed_jobs/i, /FROM "sessions"/ ].map(&:freeze).freeze
      SQL_SKIP_STICKINESS_MATCHERS = [] unless defined?( SQL_SKIP_STICKINESS_MATCHERS )
      CUSTOM_SQL_SKIP_STICKINESS_MATCHERS  = SQL_SKIP_STICKINESS_MATCHERS +
        [/FROM "sessions"/i].map(&:freeze).freeze

      # overriding this MakaraAbstractAdapter method with an extended
      # set of patterns whose matched queries will always run on the primary
      def sql_primary_matchers
        CUSTOM_SQL_PRIMARY_MATCHERS
      end

      # overriding this MakaraAbstractAdapter method with an extended
      # set of patterns whose matched queries will not trigger stickiness
      def sql_skip_stickiness_matchers
        CUSTOM_SQL_SKIP_STICKINESS_MATCHERS
      end

    end
  end
end

# enable a replica toggle and context refresh toggle
module ActiveRecord
  module ConnectionAdapters
    class MakaraPostgisAdapter < ActiveRecord::ConnectionAdapters::MakaraAbstractAdapter

      attr_reader :replica_disabled
      attr_reader :context_refresh
      attr_reader :last_context_refresh

      # added method than can be used to force all queries to be run against the primary
      def disable_replica
        @replica_enabled = false
      end

      # added method than can be used to allow queries to be run against replicas
      def enable_replica
        @replica_enabled = true
      end

      # added method to be used mainly for scripts, delayed jobs, etc.
      # When running in a non-web context, makara will never attempt to refresh
      # its context. Meaning if stickiness is enabled and a query gets run
      # against the primary, all other queries will be run against the primary
      # forever, regardless of the primary_ttl. This method allows a context
      # refresh check to run which will reasses if connection primary_ttl has
      # expired and queries can be run against replicas again
      def enable_context_refresh
        @context_refresh = true
      end

      # added method to disable context refreshing
      def disable_context_refresh
        @context_refresh = false
      end

      # overriding this method to enforce the @replica_enabled toggle, and to
      # enable context refreshing so longer-running non-web code does not get
      # stuck to the primary for too long
      def needs_primary?(method_name, args)
        return true if !@replica_enabled
        # if primary_ttl is defined, and there hasn't been a context refresh or
        # the last refresh was longer than primary_ttl ago, refresh the context
        # to allow replicas to be queried again
        if @ttl && @context_refresh && (!@last_context_refresh || ( Time.now - @last_context_refresh ) > @ttl )
          Makara::Context.next
          @last_context_refresh = Time.now
        end
        super
      end
    end
  end
end

class ActiveRecord::ConnectionAdapters::PostGISAdapter
  # makara defines this method on its DB proxy class, but it won't exist in
  # an environment that doesn't use makara configuration in database.yml. So
  # stub the method to avoid checking if makara is being used everwhere we
  # want to use without_sticking
  def without_sticking
    yield
  end

  # same for these added methods
  def enable_replica; end
  def disable_replica; end
end

module Makara
  class Middleware

    protected

    # overridding this method to skip the context-preserving middleware for ping requests
    def ignore_request?(env)
      if defined?(Rails)
        return true if env["PATH_INFO"] == "/ping"
        if Rails.try(:application).try(:config).try(:assets).try(:prefix)
          if env["PATH_INFO"].to_s =~ /^#{Rails.application.config.assets.prefix}/
            return true
          end
        end
      end
      false
    end
  end
end
