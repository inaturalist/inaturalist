module INatAPIService

  ENDPOINT = CONFIG.node_api_host
  TIMEOUT = 8

  def self.identifications(params={})
    return INatAPIService.get("/identifications", params)
  end

  def self.identifications_categories(params={})
    return INatAPIService.get("/identifications/categories", params)
  end

  def self.observations(params={})
    return INatAPIService.get("/observations", params)
  end

  def self.observations_observers(params={})
    return INatAPIService.get("/observations/observers", params)
  end

  def self.observations_species_counts(params={})
    return INatAPIService.get("/observations/species_counts", params)
  end

  def self.get_json( path, params = {}, retries = 3 )
    url = "http://" + INatAPIService::ENDPOINT + path;
    unless params.blank? || !params.is_a?(Hash)
      url += "?" + params.map{|k,v| "#{k}=#{[v].flatten.join(',')}"}.join("&")
    end
    uri = URI(url)
    begin
      timed_out = Timeout::timeout(INatAPIService::TIMEOUT) do
        response = Net::HTTP.get_response(uri)
        if response.code == "200"
          return response.body
        end
      end
    rescue
    end
    if retries.is_a?(Fixnum) && retries > 0
      return INatAPIService.get_json( path, params, retries - 1 )
    end
    false
  end

  def self.get( path, params = {}, retries = 3 )
    OpenStruct.new_recursive( JSON.parse( get_json( path, params, retries ) ) || {} )
  end
end
