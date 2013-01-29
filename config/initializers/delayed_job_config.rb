# monkey patch BufferedLogger to allow a custom formatter
class ActiveSupport::BufferedLogger
  def formatter=(formatter)
    @log.formatter = formatter
  end
end

# ensure DJ is logging to the right file
Delayed::Worker.logger = ActiveSupport::BufferedLogger.new("log/delayed_job.log", Rails.logger.level)
if caller.last =~ /delayed_job/
  # create a custom formatter than includes the pid
  # from http://cbpowell.wordpress.com/2012/04/05/beautiful-logging-for-ruby-on-rails-3-2/
  class DJFormatter
    def call(severity, time, progname, msg)
      formatted_severity = sprintf("%-5s","#{severity}")
      "[#{formatted_severity} pid:#{$$}] #{msg.strip}\n"
    end
  end
  Delayed::Worker.logger.formatter = DJFormatter.new

  # log AR calls to the log file
  ActiveRecord::Base.logger = Delayed::Worker.logger
end
