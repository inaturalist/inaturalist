require "socket"

module Logstasher
  def self.logger
    return @logger if @logger
    @logger = Logger.new("log/#{ Rails.env }.logstash.log")
    @logger.formatter = proc do |severity, datetime, progname, msg|
      "#{ msg }\n"
    end
    @logger
  end

  def self.hostname
    # Cache the nodename so we don't incur the overhead more than once
    @hostname ||= Socket.gethostname.gsub(/\./,'-')
  end

  def self.write_exception(exception)
    Logstasher.logger.debug({
      "@timestamp": Time.now,
      version: 1,
      error_type: exception.class.name,
      message: [ exception.class.name, exception.message ].join(": "),
      backtrace: exception.backtrace.join("\n")
    }.to_json)
  end

  def self.write_action_controller_log(args)
    begin
      payload = args[4]
      format = payload[:format] || "all"
      format = "all" if format == "*/*"
      saved_params = Hash[
        payload[:params].delete_if{ |k,v|
          # remove the blank and common or otherwise indexed params
          v.blank? ||
          [ :controller, :action, :utf8, :authenticity_token ].include?(k.to_sym)
        }.map{ |k,v|
          # flatten out nested object and complex params like uploads
          [ k, v.to_s ]
        }]
      parsed_user_agent = UserAgent.parse(payload[:user_agent])
      Logstasher.logger.debug({
        "@timestamp": args[1],
        version: 1,
        start_time: args[1],
        end_time: args[2],
        pid: $$,
        session: payload[:session],
        clientip: payload[:clientip],
        host: Logstasher.hostname,
        http_host: payload[:http_host],
        http_referer: payload[:http_referer],
        browser: parsed_user_agent ? parsed_user_agent.browser : nil,
        browser_version: parsed_user_agent ? parsed_user_agent.version.to_s : nil,
        platform: parsed_user_agent ? parsed_user_agent.platform : nil,
        user_agent: payload[:user_agent],
        user_id: payload[:user_id],
        user_name: payload[:user_name],
        controller: payload[:controller],
        action: payload[:action],
        controller_action: payload[:controller] + "::" + payload[:action],
        method: (payload[:method] || payload[:params][:_method] || "GET").upcase,
        path: payload[:path],
        params: saved_params,
        format: format,
        status: payload[:status],
        view_runtime: payload[:view_runtime] ? payload[:view_runtime].round(4) : nil,
        db_runtime: payload[:db_runtime] ? payload[:db_runtime].round(4) : nil,
        elasticsearch_runtime: payload[:elasticsearch_runtime] ? payload[:elasticsearch_runtime].round(4) : nil,
        # all the other times are in milliseconds
        total_time: ((args[2] - args[1]) * 1000).round(4)
      }.to_json)
    rescue Exception => e
      Rails.logger.error "[ERROR] ActiveSupport metrics failed: #{e}"
    end
  end
end
