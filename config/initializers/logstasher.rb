require "socket"

module Logstasher

  HTTP_PARAMS_TO_STASH = [
    "HTTP_FROM", "HTTP_HOST", "HTTP_USER_AGENT", "HTTP_X_CLUSTER_CLIENT_IP",
    "HTTP_X_FORWARDED_FOR", "HTTP_X_FORWARDED_PROTO", "ORIGINAL_FULLPATH",
    "HTTP_ACCEPT_LANGUAGE", "HTTP_REFERER", "REMOTE_ADDR", "REQUEST_METHOD",
    "SERVER_ADDR", "CONTENT_LENGTH", "HTTP_ORIGIN", "HTTP_AUTHORIZATION",
    "HTTP_SSLSESSIONID", "X_MOBILE_DEVICE" ]

  IP_PARAMS = [
    "HTTP_X_CLUSTER_CLIENT_IP", "HTTP_X_FORWARDED_FOR", "REMOTE_ADDR",
    "SERVER_ADDR", "clientip"
  ]

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

  def self.ip_from_request_env(request_env)
    # try a few params for IP. Proxies will shuffle around requester IP
    %w( HTTP_X_FORWARDED_FOR HTTP_X_CLUSTER_CLIENT_IP REMOTE_ADDR ).each do |param|
      return request_env[ param ] unless request_env[ param ].blank?
    end
    nil
  end

  def self.payload_from_request(request)
    return { } unless request.is_a?(ActionDispatch::Request)
    payload = { }
    # grab nearly all the HTTP params from request.env
    payload.merge!(request.env.select{ |k,v|
      HTTP_PARAMS_TO_STASH.include?(k) && !v.blank? })
    # cleanup multiple IPs
    payload = Logstasher.split_multiple_ips(payload)
    payload[:clientip] = Logstasher.ip_from_request_env(payload)
    if request.env["HTTP_ACCEPT_LANGUAGE"]
      # there may be multiple variations of languages, plus other junk
      payload[:http_languages] = request.env["HTTP_ACCEPT_LANGUAGE"].
        split(/[;,]/).select{ |l| l =~ /^[a-z-]+$/i }.map(&:downcase).first
    end
    payload[:Via] = request.headers["Via"]
    payload[:ssl] = request.ssl?.to_s
    payload[:bot] = Logstasher.is_user_agent_a_bot?(request.user_agent)
    # this can be overwritten by merging Logstasher.payload_from_user
    payload[:logged_in] = false
    payload[:i18n_locale] = I18n.locale.to_s.downcase
    payload[:http_locale_matches_i18n] = payload[:i18n_locale] == payload[:http_languages]
    payload[:http_lang_matches_i18n] = payload[:i18n_locale] &&
      payload[:http_languages] &&
      payload[:i18n_locale].split( "-" )[0] == payload[:http_languages].split( "-" )[0]
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
      user_name: user.login,
      logged_in: true }
  end

  def self.replace_known_types!(hash)
    if hash.key?(:request)
      if hash[:request].is_a?(ActionDispatch::Request)
        hash.merge!( Logstasher.payload_from_request(hash[:request]) )
      end
      hash.delete(:request)
    end
    if hash.key?(:session)
      if hash[:session].is_a?(ActionDispatch::Request::Session)
        hash.merge!( Logstasher.payload_from_session(hash[:session]) )
      else
        hash.delete(:session)
      end
    end
    if hash.key?(:user)
      if hash[:user].is_a?(User)
        hash.merge!( Logstasher.payload_from_user(hash[:user]) )
      end
      hash.delete(:user)
    end
    hash
  end

  def self.write_hash(hash_to_write)
    return if Rails.env.test?
    hash_to_write[:subtype] ||= "Custom"
    Logstasher.replace_known_types!(hash_to_write)
    begin
      stash_hash = { end_time: Time.now, pid: $$ }.
        delete_if{ |k,v| v.blank? }.merge(hash_to_write)
      Logstasher.logger.debug(stash_hash.to_json)
    rescue Exception => e
      Rails.logger.error "[ERROR] Logstasher.write_hash failed: #{e}"
    end
  end

  def self.write_exception(exception, custom={})
    return if Rails.env.test?
    Logstasher.replace_known_types!(custom)
    begin
      Logstasher.write_hash( custom.merge({
        "@timestamp": Time.now,
        subtype: "Exception",
        error_type: exception.class.name,
        error_message: [ exception.class.name, exception.message ].join(": "),
        backtrace: exception.backtrace ? exception.backtrace[0...15].join("\n") : nil
      }))
    rescue Exception => e
      Rails.logger.error "[ERROR] Logstasher.write_exception failed: #{e}"
    end
  end

  def self.delayed_job(job, custom={})
    return if Rails.env.test?
    begin
      Logstasher.write_hash( custom.merge({
        subtype: custom[:job_duration] ? "DelayedJobDuration" : "DelayedJob"
      }).merge(job.dashboard_info))
    rescue Exception => e
      Rails.logger.error "[ERROR] Logstasher.delayed_job failed: #{e}"
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
          # remove bank params, binary data params, and common or otherwise indexed params
          v.blank? ||
          v.to_s.match( /^data:/ ) ||
          [ :controller, :action, :utf8, :authenticity_token ].include?(k.to_sym)
        }.map{ |k,v|
          # flatten out nested object and complex params like uploads
          [ k, v.to_s ]
        }]
      payload.merge!({
        "@timestamp": args[1],
        subtype: "ActionController",
        end_time: args[2],
        controller_action: payload[:controller] + "::" + payload[:action],
        method: (payload[:method] || payload[:params][:_method] || "GET").upcase,
        params_string: saved_params.any? ? saved_params.to_json : nil,
        param_keys: saved_params.keys,
        format: format,
        view_runtime: payload[:view_runtime] ? payload[:view_runtime].round(4) : 0.0,
        db_runtime: payload[:db_runtime] ? payload[:db_runtime].round(4) : 0.0,
        elasticsearch_runtime: payload[:elasticsearch_runtime] ? payload[:elasticsearch_runtime].round(4) : 0.0,
        # all the other times are in milliseconds
        total_time: ((args[2] - args[1]) * 1000).round(4),
        status_code: payload[:status]
      })
      # params are stored as a string in `params_string`,
      # so don't also store them as an object
      payload.delete(:status)
      payload.delete(:params)
      payload[:remainder_time] = (payload[:total_time] - payload[:db_runtime] -
        payload[:view_runtime] - payload[:elasticsearch_runtime]).round(4)
      Logstasher.write_hash(payload)
    rescue Exception => e
      Rails.logger.error "[ERROR] Logstasher.write_action_controller_log failed : #{e}"
    end
  end

  def self.is_user_agent_a_bot?(user_agent)
    !![ "(bot|spider|pinger)\/", "(yahoo|ruby|newrelicpinger|python|lynx|crawler)" ].
      detect { |bot| user_agent =~ /#{ bot }/i }
  end

  def self.original_ip_in_list(ip_string)
    return nil unless ip_string.is_a?(String)
    # sometimes IP fields contain multiple IPs delimited by commas
    ip_string.split(",").last.strip
  end

  def self.split_multiple_ips(payload)
    extra_params = { }
    payload.each do |k,v|
      if IP_PARAMS.include?(k)
        first_ip = Logstasher.original_ip_in_list(v)
        if first_ip && first_ip != v
          payload[k] = first_ip
          extra_params["#{k}_ALL"] = v.split(",").map(&:strip)
        end
      end
    end
    payload.merge(extra_params)
  end

end
