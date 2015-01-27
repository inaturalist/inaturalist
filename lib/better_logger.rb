# monkey patch the default logger to include a PID
# based on https://gist.github.com/1091527
# require 'active_support/buffered_logger'
module BetterLogger
  def add(severity, message = nil, progname = nil, &block)
    message = (message || (block && block.call) || progname).to_s
    log = "[%s] %s" % [$$, message.gsub(/^\n+/, '')]
    super(severity, log, progname, &block)
  end

  class Railtie < ::Rails::Railtie
    initializer :better_logger, :after => :initialize_logger do |app|
      Rails.logger.extend(BetterLogger)
    end
  end
end
