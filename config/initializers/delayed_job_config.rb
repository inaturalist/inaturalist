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

# enable a limit on how many jobs a worker can do before its forced to stop
if CONFIG.delayed_jobs && CONFIG.delayed_jobs.job_limit
  module Delayed
    class Worker
      cattr_accessor :job_limit, :jobs_run
      self.job_limit = CONFIG.delayed_jobs.job_limit
      self.jobs_run = 0

      protected

      def reserve_and_run_one_job
        job = reserve_job
        success = self.class.lifecycle.run_callbacks(:perform, self, job) { run(job) } if job
        self.jobs_run += 1
        # stop the worker if it has reached its job_limi
        if self.job_limit && self.jobs_run >= self.job_limit
          stop
        end
        success
      end

    end
  end
end
