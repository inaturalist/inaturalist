# Subscribe to all action_controller events and send various data to be measured
ActiveSupport::Notifications.subscribe /process_action.action_controller/ do |*args|
  Logstasher.write_action_controller_log(args)
end

# Deprecation warnings are published as notifications in production
# (config.active_support.deprecation = :notify) and are otherwise invisible.
# Log them so deprecated code paths exercised by real traffic can be found and
# fixed, then added to the curated disallowed list in config/application.rb,
# before the next Rails upgrade phase
ActiveSupport::Notifications.subscribe "deprecation.rails" do | _name, _start, _finish, _id, payload |
  Logstasher.write_custom_log(
    "Deprecation warning: #{payload[:message]}",
    backtrace: payload[:callstack]&.first( 5 )&.map( &:to_s )
  )
end
