require 'socket'

# This module will handle sending the measurements to Statsd
module StatsdIntegration
  def self.send_event_to_statsd(name, payload)
    if defined?(STATSD) && STATSD.is_a?(Statsd)
      action = payload[:action] || :increment
      measurement = payload[:measurement]
      value = payload[:value]
      key_name = "#{name.to_s}.#{measurement}"
      batch = Statsd::Batch.new(STATSD)
      batch.__send__ action.to_s, "#{nodename}.#{key_name}", (value || 1)
      batch.flush
    end
  end

  def self.nodename
    # Cache the nodename so we don't incur the overhead more than once
    @@nodename ||= Socket.gethostname.gsub(/\./,'-')
  end
end

# Send all types of performance events to StatsdIntegration
ActiveSupport::Notifications.subscribe /performance/ do |name, start, finish, id, payload|
  if defined?(STATSD) && STATSD.is_a?(Statsd)
    StatsdIntegration.send_event_to_statsd(name, payload)
  end
end

# Subscribe to all action_controller events and send various data to be measured
ActiveSupport::Notifications.subscribe /process_action.action_controller/ do |*args|
  if defined?(STATSD) && STATSD.is_a?(Statsd)
    event = ActiveSupport::Notifications::Event.new(*args)
    controller = event.payload[:controller]
    action = event.payload[:action]
    method = event.payload[:method] || "GET"
    format = event.payload[:format] || "all"
    format = "all" if format == "*/*"
    status = event.payload[:status]
    key = "#{controller}.#{action}.#{method}.#{format}"
    ActiveSupport::Notifications.instrument :performance,
                                            :action => :timing,
                                            :measurement => "#{key}.total_duration",
                                            :value => event.duration
    ActiveSupport::Notifications.instrument :performance,
                                            :action => :timing,
                                            :measurement => "#{key}.db_time",
                                            :value => event.payload[:db_runtime]
    ActiveSupport::Notifications.instrument :performance,
                                            :action => :timing,
                                            :measurement => "#{key}.view_time",
                                            :value => event.payload[:view_runtime]
    ActiveSupport::Notifications.instrument :performance,
                                            :measurement => "#{key}.status.#{status}"
  end
end
