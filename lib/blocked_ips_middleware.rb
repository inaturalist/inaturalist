# frozen_string_literal: true

class BlockedIpsMiddleware
  def initialize( app )
    @app = app
  end

  def call( request_env )
    client_ip = ip_from_request_env( request_env )
    if blocked_ips.include?( client_ip )
      return [403, { "Content-Type" => "text/plain" }, ["Forbidden"]]
    end

    @app.call( request_env )
  end

  private

  def ip_from_request_env( request_env )
    request = Rack::Request.new( request_env )
    %w(HTTP_X_FORWARDED_ORIGINAL_FOR HTTP_X_FORWARDED_FOR HTTP_X_CLUSTER_CLIENT_IP REMOTE_ADDR).each do | param |
      return request_env[param].split( "," ).first unless request_env[param].blank?
    end
    request.ip
  end

  def blocked_ips
    Rails.cache.fetch( "blocked_ips", expires_in: 60.minutes ) do
      BlockedIp.pluck( :ip )
    end
  end
end
