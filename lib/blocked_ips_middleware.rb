# frozen_string_literal: true

class BlockedIpsMiddleware
  def initialize( app )
    @app = app
  end

  def call( request_env )
    client_ip = Logstasher.ip_from_request_env( request_env )
    if blocked_ips.include?( client_ip )
      return render_error_403_with_haml
    end

    @app.call( request_env )
  end

  private

  def blocked_ips
    Rails.cache.fetch( "blocked_ips", expires_in: 60.minutes ) do
      BlockedIp.pluck( :ip )
    end
  end

  def render_error_403_with_haml
    haml_file = Rails.root.join( "app", "views", "errors", "error_403.html.haml" )
    haml_content = File.read( haml_file )

    engine = Haml::Engine.new( haml_content )
    html = engine.render

    [403, { "Content-Type" => "text/html" }, [html]]
  end
end
