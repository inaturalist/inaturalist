# frozen_string_literal: true

module INatAPIService
  module V2
    class Error < StandardError; end

    class Client
      BASE_URL = "https://api.inaturalist.org/v2"

      attr_reader :api

      def initialize
        @api = Faraday.new BASE_URL
      end

      # GETs taxon by id
      #
      # @param [String] id Taxon id(s). Multiple ids separated by comma
      # @param [String] fields Fields to include in response
      # @return [Hash] parsed JSON response
      def get_taxon_by_id( id, fields: "all" )
        get "taxa/#{id}?#{fields_from_opts fields}"
      end

      private

      def fields_from_opts( fields )
        return "" unless fields.present?

        case fields
        when String
          "fields=#{fields}"
        when Array
          "fields=#{fields.join ','}"
        else
          ""
        end
      end

      def get( url )
        response = api.get url

        api_failure! url: url, status: response.status, message: response.body unless response.success?

        parse_response response
      end

      def parse_response( resp )
        JSON.parse resp.body, symbolize_names: true
      rescue JSON::ParserError => e
        Rails.logger.error "[ERROR] Failure to parse iNat API response: #{e}"
        api_failure! url: resp.env.url.to_s, message: e.message
      end

      def api_failure!( url: nil, body: nil, status: nil, message: nil )
        raise INatAPIService::V2::Error.new url: url, body: body, status: status, message: message
      end
    end
  end
end
