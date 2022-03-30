# don't indicate cached queries are being run against the primary DB
module MakaraLoggingSubscriber
  # See https://github.com/instacart/makara/blob/e45ba090fce998dad9e9a2759426f4695009cfae/lib/makara/logging/subscriber.rb#L23
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
      CUSTOM_SQL_PRIMARY_MATCHERS = SQL_PRIMARY_MATCHERS + [/delayed_jobs/i].map(&:freeze).freeze
      SQL_SKIP_STICKINESS_MATCHERS = [] unless defined?( SQL_SKIP_STICKINESS_MATCHERS )
      CUSTOM_SQL_SKIP_STICKINESS_MATCHERS  = SQL_SKIP_STICKINESS_MATCHERS + [/FROM "sessions"/i].map(&:freeze).freeze

      def sql_primary_matchers
        CUSTOM_SQL_PRIMARY_MATCHERS
      end

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

      def disable_replica
        @replica_enabled = false
      end

      # replicas will only be used if enable_replica is called
      def enable_replica
        @replica_enabled = true
      end

      # when running in a non-web context, makara will never attempt to refresh
      # its context, meaning if stickiness is enabled and a query gets run
      # against the primary, all other queries will be run against the primary
      # forever, regardless of the primary_ttl. This method allow a context
      # refresh check to run to allow connections to fall back to using replicas
      # after primary_ttl has expired
      def enable_context_refresh
        @context_refresh = true
      end

      def disable_context_refresh
        @context_refresh = false
      end

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

      # def should_stick?(method_name, args)
      #   return false unless sticky?
      #   sql = coerce_query_to_sql_string(args.first)
      #   return true if sql_primary_matchers.any?{|m| sql =~ m }
      #   super
      # end

    end
  end
end

class ActiveRecord::ConnectionAdapters::PostGISAdapter
  # makara defines this method on its DB proxy class, but it won't exist in
  # an environment that doesn't use makara. So stub the method to avoid checking
  # if makara is being used every time we want to use without_sticking
  def without_sticking
    yield
  end
end

module Makara
  class Middleware

    protected

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
