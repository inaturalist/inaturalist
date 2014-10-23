Delayed::Worker.default_queue_name = "default"
Delayed::Worker.max_attempts = 10
Delayed::Worker.destroy_failed_jobs = false

# # # monkey patch BufferedLogger to allow a custom formatter
# # class ActiveSupport::BufferedLogger
# #   def formatter=(formatter)
# #     @log.formatter = formatter
# #   end
# # end

# # ensure DJ is logging to the right file
# # Delayed::Worker.logger = ActiveSupport::BufferedLogger.new("log/delayed_job.log", Rails.logger.level)
# Delayed::Worker.logger ||= Logger.new(File.join(Rails.root, 'log', 'delayed_job.log'))
# if caller.last =~ /delayed_job/
#   # # create a custom formatter than includes the pid
#   # # from http://cbpowell.wordpress.com/2012/04/05/beautiful-logging-for-ruby-on-rails-3-2/
#   # class DJFormatter
#   #   def call(severity, time, progname, msg)
#   #     formatted_severity = sprintf("%-5s","#{severity}")
#   #     "[#{formatted_severity} pid:#{$$}] #{msg.strip}\n"
#   #   end
#   # end
#   # Delayed::Worker.logger.formatter = DJFormatter.new

#   Rails.logger.debug "[DEBUG] Delayed::Worker.logger: #{Delayed::Worker.logger}"
#   # log AR calls to the log file
#   ActiveRecord::Base.logger = Delayed::Worker.logger
#   Rails.logger = Delayed::Worker.logger
# end
