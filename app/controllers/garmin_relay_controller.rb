# frozen_string_literal: true

# Relays browser requests to the Garmin Connect Personal API, which answers
# every CORS preflight with 403. The geotrack JS library does the work (key
# exchange, activity search, unzipping); this only copies bytes. Nothing is
# parsed or stored, and the Authorization header, which carries the user's
# Garmin API key or access token, is removed from the request env before
# logging (Logstasher stashes HTTP_AUTHORIZATION) or OAuth lookups see it.
class GarminRelayController < ApplicationController
  GARMIN_URL = "https://personal.connectapi.garmin.com"
  FLAG = :client_garmin_personal_api
  # The only Garmin endpoints geotrack calls
  ALLOWED_PATHS = {
    "POST" => %r{\Apersonalapitoken-service/personal-api/personal-api-key/token\z},
    "GET" => %r{\A(activitylist-service/activities/search/activities|download-service/files/activity/\d+)\z}
  }.freeze
  RESPONSE_HEADERS = %w(Content-Type Retry-After).freeze
  TIMEOUT = 30

  # Before CSRF verification too, which skips requests with an Authorization header
  prepend_before_action :take_garmin_authorization
  before_action :authenticate_user!
  before_action :require_flag

  def relay
    pattern = ALLOWED_PATHS[request.method]
    return head :not_found unless pattern&.match?( params[:path].to_s )

    garmin_response = forward
    return head :bad_gateway unless garmin_response

    RESPONSE_HEADERS.each do | name |
      value = garmin_response.headers[name.downcase.tr( "-", "_" ).to_sym]
      response.headers[name] = value if value
    end
    response.headers["Cache-Control"] = "no-store"
    send_data garmin_response.body,
      status: garmin_response.code,
      type: garmin_response.headers[:content_type] || "application/octet-stream",
      disposition: "inline"
  end

  private

  def take_garmin_authorization
    @garmin_authorization = request.env.delete( "HTTP_AUTHORIZATION" )
  end

  def require_flag
    head :not_found unless FeatureFlagging.enabled?( FLAG, current_user )
  end

  def forward
    url = "#{GARMIN_URL}/#{params[:path]}"
    url += "?#{request.query_string}" if request.query_string.present?
    headers = { accept: request.headers["Accept"] || "*/*" }
    headers[:authorization] = @garmin_authorization if @garmin_authorization
    RestClient::Request.execute(
      method: request.method.downcase.to_sym,
      url: url,
      headers: headers,
      timeout: TIMEOUT,
      max_redirects: 0
    )
  rescue RestClient::ExceptionWithResponse => e
    e.response
  rescue RestClient::Exception, SocketError, SystemCallError, OpenSSL::SSL::SSLError
    nil
  end
end
