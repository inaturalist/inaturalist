# Subscribe to all action_controller events and send various data to be measured
ActiveSupport::Notifications.subscribe /process_action.action_controller/ do |*args|
  Logstasher.write_action_controller_log(args)
end
