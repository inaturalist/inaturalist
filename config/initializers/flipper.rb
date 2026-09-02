# frozen_string_literal: true

# Feature flags. App code reads flags through lib/feature_flagging.rb rather
# than calling Flipper directly. See WEB-1074 and
# doc/feature_flags_ab_options.md.

# The adapter block is lazy, so booting the app, precompiling assets, and
# running rake tasks never touch the flipper tables. That matters because our
# container entrypoint does not run db:migrate -- a new image can boot before
# the tables exist. FeatureFlagging is referenced only inside the block so
# nothing under lib/ autoloads at boot ( classic autoloader ).
#
# FeatureFlagging.build_adapter ( WEB-1171 ): a fail-closed, logging wrapper
# over a memcached read-through cache ( FeatureFlagging::CACHE_TTL seconds,
# only where Rails.cache is memcached -- production, not staging's file store )
# over instrumented ActiveRecord.
Flipper.configure do | config |
  config.adapter { FeatureFlagging.build_adapter }
end

flipper_config = Rails.application.config.flipper

# One gate read per flag per request instead of one per check.
flipper_config.memoize = true

# Preload is left at flipper's default ( true ), so the Memoizer middleware
# loads every registered flag with one get_all per request -- one memcached
# read, or one LEFT JOIN on a cache miss -- instead of one SELECT per flag
# checked. WEB-1074 turned it off because that read runs outside
# FeatureFlagging's fail-closed rescue and a missing table would have 500ed
# every page; FeatureFlagging::FailClosedAdapter now covers it, logging and
# reporting every flag off instead. FLIPPER_PRELOAD=false is a no-deploy kill
# switch. Note preload only covers rows in flipper_features: a KNOWN_FLAGS key
# nobody has registered still costs one read of its own per request.

# Never warn or raise for a flag with no row yet; an unregistered flag is simply
# off. Flipper defaults this to :warn in the development environment, which is
# also what our staging servers run as.
flipper_config.strict = false

# Flag reads are hot and uninteresting; don't log every gate check.
flipper_config.log = false

# Per-request flag-read telemetry: the feature_flag_* fields that
# ApplicationController#append_info_to_payload merges into the Logstasher
# request record. Constants resolve inside the blocks so the subscriptions
# survive a code reload in development.
ActiveSupport::Notifications.subscribe( "feature_operation.flipper" ) do | event |
  FeatureFlagging::Telemetry.record_feature_operation( event )
end
ActiveSupport::Notifications.subscribe( "adapter_operation.flipper" ) do | event |
  FeatureFlagging::Telemetry.record_adapter_operation( event )
end

# Lets an admin enable a flag for staff only from the admin UI. Duck-typed
# rather than referencing User, so this file loads no app constants at boot
# ( we use the classic autoloader ).
unless Flipper.group_exists?( :admins )
  Flipper.register( :admins ) do | actor |
    actor.respond_to?( :is_admin? ) && actor.is_admin?
  end
end

Flipper::UI.configure do | config |
  config.banner_text = "#{Rails.env} — flag changes take effect on the next request"
  config.banner_class = "danger"

  # Require typing the flag name before enabling it for everyone.
  config.confirm_fully_enable = true

  # Deleting a feature drops its gate history and turns it off everywhere with
  # no record of what it was. Disabling is the reversible equivalent.
  config.feature_removal_enabled = true

  # Both of these reach outside the app: the version check loads a script that
  # phones home for the latest flipper release from the admin's browser (also a
  # CSP concern, see config/initializers/content_security_policy.rb), and the
  # recommendation renders a Flipper Cloud ad.
  config.version_check_enabled = false
  config.cloud_recommendation = false
end
