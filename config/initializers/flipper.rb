# frozen_string_literal: true

# Feature flags. App code reads flags through lib/feature_flagging.rb rather
# than calling Flipper directly. See WEB-1074 and
# doc/feature_flags_ab_options.md.

# The adapter block is lazy, so booting the app, precompiling assets, and
# running rake tasks never touch the flipper tables. That matters because our
# container entrypoint does not run db:migrate -- a new image can boot before
# the tables exist.
Flipper.configure do | config |
  config.adapter { Flipper::Adapters::ActiveRecord.new }
end

flipper_config = Rails.application.config.flipper

# One gate read per flag per request instead of one per check.
flipper_config.memoize = true

# Deliberately off, overriding flipper's default of true. Preloading queries
# flipper_gates from Rack middleware on every request, outside
# FeatureFlagging's fail-closed rescue, so a missing table would be a 500 on
# every page rather than "all flags off". Revisit once the tables exist in every
# environment and we have more than a handful of flags.
flipper_config.preload = false

# Never warn or raise for a flag with no row yet; an unregistered flag is simply
# off. Flipper defaults this to :warn in the development environment, which is
# also what our staging servers run as.
flipper_config.strict = false

# Flag reads are hot and uninteresting; don't log every gate check.
flipper_config.log = false

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
