# frozen_string_literal: true

# Lazy adapter block: app can boot before db:migrate completes (classic autoloader doesn't preload FeatureFlagging).
Flipper.configure do | config |
  config.adapter { FeatureFlagging.build_adapter }
end

flipper_config = Rails.application.config.flipper

# One gate read per flag per request instead of one per check.
flipper_config.memoize = true

# Preload one get_all per request (safe via FailClosedAdapter); unregistered flags cost extra reads.
flipper_config.strict = false

flipper_config.log = false

# Telemetry: constants in blocks survive reloads; subscriptions feed feature_flag_* into Logstasher.
ActiveSupport::Notifications.subscribe( "feature_operation.flipper" ) do | event |
  FeatureFlagging::Telemetry.record_feature_operation( event )
end
ActiveSupport::Notifications.subscribe( "adapter_operation.flipper" ) do | event |
  FeatureFlagging::Telemetry.record_adapter_operation( event )
end

# Duck-typed to avoid loading User at boot (classic autoloader).
unless Flipper.group_exists?( :admins )
  Flipper.register( :admins ) do | actor |
    actor.respond_to?( :is_admin? ) && actor.is_admin?
  end
end

Flipper::UI.configure do | config |
  config.banner_text = "#{Rails.env} — flag changes take effect on the next request"
  config.banner_class = "danger"

  config.confirm_fully_enable = true
  config.feature_removal_enabled = true

  # Disabled to avoid external script (CSP concern) and cloud advertisement.
  config.version_check_enabled = false
  config.cloud_recommendation = false
end
