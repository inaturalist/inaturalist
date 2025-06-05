# frozen_string_literal: true

class SendgridService
  attr_reader :timeout, :service_name

  SERVICE_VERSION = 3.0

  ENDPOINT = "https://api.sendgrid.com/v3/"

  def self.method_missing( method, * )
    @service ||= new
    @service.send( method, * )
  end

  def self.respond_to_missing?( method, include_private = true )
    @service ||= new
    @service.respond_to?( method, include_private )
  end

  def initialize( options = {} )
    @service_name = "Sendgrid API"
    @timeout ||= options[:timeout] || 5
    @debug ||= options[:debug]
  end

  def delete_group_suppression( email, group_id )
    request( :delete, "#{ENDPOINT}/asm/groups/#{group_id}/suppressions/#{email}" )
  end

  def post_group_suppression( email, group_id )
    request( :post, "#{ENDPOINT}/asm/groups/#{group_id}/suppressions", {
      recipient_emails: [email]
    } )
  end

  def asm_group_ids
    return @group_ids if @group_ids

    groups_resp = request( :get, "https://api.sendgrid.com/v3/asm/groups" )
    @group_ids = JSON.parse( groups_resp ).each_with_object( {} ) do | group, memo |
      memo[group["name"].parameterize.underscore] = group["id"]
    end
  end

  private

  def request( method, endpoint, payload = nil )
    RestClient::Request.execute(
      method: method,
      url: endpoint,
      payload: payload&.to_json,
      content_type: :json,
      accept: :json,
      headers: {
        "Authorization" => "Bearer #{CONFIG.sendgrid.api_key}"
      },
      timeout: @timeout
    )
  end
end
