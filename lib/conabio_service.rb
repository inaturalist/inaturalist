# frozen_string_literal: true

require "timeout"
require "uri"

class ConabioService
  TAXON_SERVICE = "https://enciclovida.mx/busquedas/resultados.json?busqueda=basica&nombre=[NAME]"
  DESCRIPTION_SERVICE = "https://enciclovida.mx/especies/[ID]/descripcion?from=conabio_inat"
  SERVICE_VERSION = 1.0

  attr_reader :timeout, :service_name

  def initialize( options = {} )
    @service_name = "CONABIO"
    @timeout = 5
    @debug = options[:debug] || false
    @taxon_api_endpoint = ApiEndpoint.find_or_create_by!(
      title: "Enciclovida MX Taxa",
      documentation_url: "https://enciclovida.mx/",
      base_url: "https://enciclovida.mx/busquedas/resultados.json",
      cache_hours: 720
    )
    @description_api_endpoint = ApiEndpoint.find_or_create_by!(
      title: "Enciclovida MX Descriptions",
      documentation_url: "https://enciclovida.mx/",
      base_url: "https://enciclovida.mx/especies",
      cache_hours: 720
    )
  end

  #
  # Search for the specific cientific name
  #
  def search( taxon_name )
    begin
      taxon_response_body = MetaService.fetch_request_uri(
        request_uri: URI.parse( TAXON_SERVICE.sub( "[NAME]", CGI.escape( taxon_name ) ) ),
        timeout: @timeout,
        api_endpoint: @taxon_api_endpoint,
        user_agent: "#{Site.default.name}/#{self.class}/#{SERVICE_VERSION}",
        raw_response: true
      )
      taxon_response_json = JSON.parse( taxon_response_body )
      unless taxon_response_json && taxon_response_json["taxa"] &&
          !taxon_response_json["taxa"].empty?
        return
      end

      taxon_id = taxon_response_json["taxa"].first["IdNombre"]

      description_body = MetaService.fetch_request_uri(
        request_uri: URI.parse( DESCRIPTION_SERVICE.sub( "[ID]", taxon_id.to_s ) ),
        timeout: @timeout,
        api_endpoint: @description_api_endpoint,
        user_agent: "#{Site.default.name}/#{self.class}/#{SERVICE_VERSION}",
        raw_response: true
      )
      if description_body && description_body.strip == "<div></div>"
        return
      end

      description_body
    rescue Timeout::Error
      raise Timeout::Error, "#{@service_name} didn't respond within #{@timeout} seconds."
    end
  end
end
