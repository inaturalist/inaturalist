# Subscribe to all action_controller events and send various data to be measured
ActiveSupport::Notifications.subscribe /process_action.action_controller/ do |*args|
  Logstasher.write_action_controller_log(args)
end

# Deprecation warnings are published as notifications in production.
ActiveSupport::Notifications.subscribe "deprecation.rails" do | _name, _start, _finish, _id, payload |
  Logstasher.write_custom_log(
    "Deprecation warning: #{payload[:message]}",
    backtrace: payload[:callstack]&.first( 5 )&.map( &:to_s )
  )
end
