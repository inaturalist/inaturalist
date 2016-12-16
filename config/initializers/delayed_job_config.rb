require "dj_logstash_plugin"

Delayed::Worker.plugins << DJLogstashPlugin

Delayed::Worker.default_queue_name = "default"
Delayed::Worker.max_attempts = 10
Delayed::Worker.destroy_failed_jobs = false
Delayed::Worker.max_run_time = 10.hours

# Set up the logger
Delayed::Worker.logger = Logger.new(File.join(Rails.root, 'log', 'delayed_job.log'))

# Customize the output to be a litte less verbose
Delayed::Worker.logger.formatter = proc do |severity, datetime, progname, msg|
  formatted_severity = sprintf("%-5s","#{severity}")
  "[#{formatted_severity} pid:#{$$}] #{ msg.strip }\n"
end

# If this is specifically a delayed job process, redirect all logs
if caller.last =~ /delayed_job/
  # Ensure all logs for this process write to the delayed job log
  ActiveRecord::Base.logger = Delayed::Worker.logger
  Rails.logger = Delayed::Worker.logger
  ActiveSupport::Cache::Store.logger = Delayed::Worker.logger
  Rails.logger.level = Logger::WARN if Rails.env.production?
end
