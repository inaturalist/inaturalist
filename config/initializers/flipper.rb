# frozen_string_literal: true

# Lazy adapter block: app can boot before db:migrate completes (classic autoloader doesn't preload FeatureFlagging).
Flipper.configure do | config |
  config.adapter { FeatureFlagging.build_adapter }
end

flipper_config = Rails.application.config.flipper

# One gate read per flag per request instead of one per check.
flipper_config.memoize = true

# One get_all per request (safe via FailClosedAdapter); the feature set it loads is also the flag registry.
flipper_config.preload = true

# App-side checks treat unknown keys as off with a warning; see FeatureFlagging.enabled?.
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

# English literals below: Flipper::UI is an untranslated third-party admin app.
Flipper::UI.configure do | config |
  config.banner_text = "#{Rails.env} — flag changes take effect on the next request. " \
    "Name a flag <code>client_…</code> to send it to web and mobile, <code>exp_…</code> to run a " \
    "control/treatment experiment; any other name is read by server code only."
  config.banner_class = "danger"

  config.descriptions_source = ->( keys ) { keys.index_with {| key | FeatureFlagging.description_for( key ) } }
  config.show_feature_description_in_list = true

  config.confirm_fully_enable = true
  config.feature_removal_enabled = true

  # Disabled to avoid external script (CSP concern) and cloud advertisement.
  config.version_check_enabled = false
  config.cloud_recommendation = false
end
