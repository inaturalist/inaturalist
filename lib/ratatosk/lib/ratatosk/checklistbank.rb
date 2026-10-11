require 'net/http'
require 'uri'
require 'json'
require 'timeout'


#
# Wrapper around ChecklistBank API. We just utilize the two COL datasets, core and extended release, from this API endpoint for now. 
#
class ChecklistBank
  API_BASE = 'https://api.checklistbank.org/dataset'.freeze

  attr_reader :timeout

  def initialize(timeout = 5, options = {})
    @timeout = timeout
    @debug   = options[:debug]
  end

  #
  # Search endpoint with fallback dataset support
  #
  def search(name, limit: 10)
    response = search_dataset(
      Ratatosk::NameProviders::ChecklistBankNameProvider::PRIMARY_DATASET_ID,
      name,
      limit
    )

    results = response['result'] || []

    #
    # fallback to COL extended release dataset
    #
    if results.blank?
      response = search_dataset(
        Ratatosk::NameProviders::ChecklistBankNameProvider::FALLBACK_DATASET_ID,
        name,
        limit
      )
    end

    response
  end

  protected

  def search_dataset(dataset_id, name, limit)
    request(
      "#{API_BASE}/#{dataset_id}/nameusage/search?" +
      URI.encode_www_form(
        q: name,
        limit: limit
      )
    )
  end

  def request(url)
    uri = URI.parse(url)

    response = nil

    begin
      Timeout.timeout(@timeout) do
        puts "DEBUG: requesting #{uri}" if @debug

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        req = Net::HTTP::Get.new(uri.request_uri)
        req['Accept'] = 'application/json'

        response = http.request(req)

        puts response.body if @debug
      end
    rescue Timeout::Error
      raise Timeout::Error,
        "ChecklistBank didn't respond within #{@timeout} seconds."
    end

    unless response.code.to_i.between?(200, 299)
      raise StandardError,
        "ChecklistBank request failed: #{response.code}"
    end

    JSON.parse(response.body)
  end
end