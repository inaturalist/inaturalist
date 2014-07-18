#encoding: utf-8
# Call the SOAP service from COANBIO

require 'timeout'
require 'uri'

class ConabioService
  def initialize(options = {})
    @service_name = 'CONABIO'
    @wsdl = 'http://conabioweb.conabio.gob.mx/webservice/conabio.wsdl'
    @key = 'La completa armonia de una obra imaginativa con frecuencia es la causa que los irreflexivos la supervaloren.'
    @timeout = 5
    @debug = options[:debug] || false
  end

  #
  # Search for the specific cientific name
  #
  def search(q)
    begin
      client=Savon.client(wsdl: @wsdl)
      begin
        Timeout::timeout(@timeout) do
          @response = client.call(:data_taxon, message: { scientific_name: URI.encode(q.gsub(' ', '_')), key: @key })
        end
      rescue Timeout::Error
        raise Timeout::Error, "Conabio didn't respond within #{@timeout} seconds."
      rescue Errno::ECONNRESET, Errno::EHOSTUNREACH => e
        Rails.logger.error "[ERROR #{Time.now}] Failed to retrieve CONABIO page: #{e}"
        return nil
      end
    rescue Savon::SOAPFault => e
      puts e.message
    end
    if @response.body[:data_taxon_response][:return].present?
      @response.body[:data_taxon_response][:return].encode('iso-8859-1').force_encoding('UTF-8').gsub(/\n/,'<br>')
    end
  end
end
