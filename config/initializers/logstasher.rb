require "socket"

module Logstasher
  def self.logger
    return if Rails.env.test?
    return @logger if @logger
    @logger = Logger.new("log/#{ Rails.env }.logstash.log")
    @logger.formatter = proc do |severity, datetime, progname, msg|
      # strings get written to the log file verbatim
      "#{ msg }\n"
    end
    @logger
  end

  def self.hostname
    # cache the nodename so we don't incur the overhead more than once
    @hostname ||= Socket.gethostname.gsub(/\./,'-')
  end

  def self.payload_from_request(request)
    return { } unless request.is_a?(ActionDispatch::Request)
    payload = { }
    # try a few params for IP. Proxies will shuffle around requester IP
    %w( HTTP_X_FORWARDED_FOR HTTP_X_CLUSTER_CLIENT_IP REMOTE_ADDR ).
      each do |param|
      next if request.env[ param ].blank?
      payload[:clientip] = request.env[ param ]
      break
    end
    # grab nearly all the HTTP params from request.env
    payload.merge!(request.env.select{ |k,v| k =~ /^[A-Z_]+$/ }.
      delete_if{ |k,v| [ "HTTP_COOKIE" ].include?(k) || v.blank? })
    if request.env["HTTP_ACCEPT_LANGUAGE"]
      # there may be multiple variations of languages, plus other junk
      payload[:http_languages] = request.env["HTTP_ACCEPT_LANGUAGE"].
        split(/[;,]/).select{ |l| l =~ /^[a-z-]+$/i }
    end
    payload[:ssl] = request.ssl?.to_s
    payload[:user_agent] = request.user_agent
    payload
  end

  def self.payload_from_session(session)
    return { } unless session.is_a?(ActionDispatch::Request::Session)
    { session: session.to_hash.select{ |k,v|
      [ :session_id, :_csrf_token ].include?(k.to_sym) } }
  end

  def self.payload_from_user(user)
    return { } unless user.is_a?(User)
    { user_id: user.id,
      user_name: user.login }
  end

  def self.replace_known_types!(hash)
    if hash[:request] && hash[:request].is_a?(ActionDispatch::Request)
      hash.merge!( Logstasher.payload_from_request(hash[:request]) )
      hash.delete(:request)
    end
    if hash[:session] && hash[:session].is_a?(ActionDispatch::Request::Session)
      hash.merge!( Logstasher.payload_from_session(hash[:session]) )
    end
    if hash[:user] && hash[:user].is_a?(User)
      hash.merge!( Logstasher.payload_from_user(hash[:user]) )
      hash.delete(:user)
    end
    hash
  end

  def self.write_hash(hash)
    return if Rails.env.test?
    hash[:subtype] ||= "Custom"
    Logstasher.replace_known_types!(hash)
    begin
      stash_hash = { "@timestamp": Time.now, version: 1,
        pid: $$, hostname: Logstasher.hostname }.
        delete_if{ |k,v| v.blank? }.merge(hash)
      Logstasher.logger.debug(stash_hash.to_json)
    rescue Exception => e
      Rails.logger.error "[ERROR] Logstasher.write_hash failed: #{e}"
    end
  end

  def self.write_exception(exception, custom={})
    return if Rails.env.test?
    begin
      Logstasher.write_hash( custom.merge({
        subtype: "Exception",
        error_type: exception.class.name,
        error_message: [ exception.class.name, exception.message ].join(": "),
        backtrace: exception.backtrace ? exception.backtrace.join("\n") : nil
      }))
    rescue Exception => e
      Rails.logger.error "[ERROR] Logstasher.write_exception failed: #{e}"
    end
  end

  def self.write_action_controller_log(args)
    return if Rails.env.test?
    begin
      payload = args[4].deep_dup
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
      Logstasher.write_hash(payload.merge({
        "@timestamp": args[1],
        subtype: "ActionController",
        start_time: args[1],
        end_time: args[2],
        browser: parsed_user_agent ? parsed_user_agent.browser : nil,
        browser_version: parsed_user_agent ? parsed_user_agent.version.to_s : nil,
        platform: parsed_user_agent ? parsed_user_agent.platform : nil,
        controller_action: payload[:controller] + "::" + payload[:action],
        method: (payload[:method] || payload[:params][:_method] || "GET").upcase,
        params: saved_params,
        format: format,
        view_runtime: payload[:view_runtime] ? payload[:view_runtime].round(4) : nil,
        db_runtime: payload[:db_runtime] ? payload[:db_runtime].round(4) : nil,
        elasticsearch_runtime: payload[:elasticsearch_runtime] ? payload[:elasticsearch_runtime].round(4) : nil,
        # all the other times are in milliseconds
        total_time: ((args[2] - args[1]) * 1000).round(4)
      }))
    rescue Exception => e
      Rails.logger.error "[ERROR] Logstasher.write_action_controller_log failed : #{e}"
    end
  end
end
