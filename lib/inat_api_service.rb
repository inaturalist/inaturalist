#encoding: utf-8

require "inat_api_service/v2/client"

module INatAPIService
  ENDPOINT = CONFIG.node_api_url
  TIMEOUT = 8

  MAPPABLE_PARAMS = [
    "acc",
    "acc_above",
    "acc_below",
    "acc_below_or_unknown",
    "apply_project_rules_for",
    "border_opacity",
    "cache",
    "captive",
    "collection_preview",
    "color",
    "created_d1",
    "created_d2",
    "created_on",
    "d1",
    "d2",
    "day",
    "endemic",
    "expansive_term_value_id",
    "expansive_without_term_value_id",
    "featured_observation_id",
    "geo",
    "geoprivacy",
    "has",
    "has[]",
    "hrank",
    "iconic_taxa",
    "id",
    "id_above",
    "ident_taxon_id",
    "ident_taxon_id_exclusive",
    "ident_user_id",
    "identifications",
    "identified",
    "introduced",
    "lat",
    "license",
    "licensed",
    "line_color",
    "line_opacity",
    "line_width",
    "list_id",
    "lng",
    "lrank",
    "members_of_project",
    "month",
    "native",
    "nelat",
    "nelng",
    "not_in_place",
    "not_in_project",
    "not_matching_project_rules_for",
    "not_user_id",
    "oauth_application_id",
    "on",
    "opacity",
    "outlink_source",
    "pcid",
    "photo_license",
    "photo_licensed",
    "photos",
    "place_id",
    "popular",
    "precision",
    "precision_offset",
    "project_id",
    "project_ids",
    "projects[]",
    "q",
    "quality_grade",
    "radius",
    "rank",
    "reviewed",
    "scaled",
    "search_on",
    "site_id",
    "skip_top_hits",
    "sound_license",
    "sounds",
    "style",
    "swlat",
    "swlng",
    "taxon_geoprivacy",
    "taxon_id",
    "taxon_ids",
    "taxon_ids[]",
    "term_id",
    "term_value_id",
    "threatened",
    "tile_size",
    "ttl",
    "unobserved_by_user_id",
    "user_after",
    "user_before",
    "user_id",
    "verifiable",
    "viewer_id",
    "viewer_id",
    "width",
    "without_field",
    "without_ident_user_id",
    "without_taxon_id",
    "without_term_value_id",
    "year"
  ]

  def self.geoip_lookup(params={}, options = {})
    options[:authorization] ||= JsonWebToken.applicationToken
    return INatAPIService.get("/geoip_lookup", params, options)
  end

  def self.identifications(params={}, options = {})
    return INatAPIService.get("/identifications", params, options)
  end

  def self.identifications_categories(params={}, options = {})
    return INatAPIService.get("/identifications/categories", params, options)
  end

  def self.observations(params={}, options = {})
    return INatAPIService.get("/observations", params, options)
  end

  def self.observations_observers(params={}, options = {})
    return INatAPIService.get("/observations/observers", params, options)
  end

  def self.observations_species_counts(params={}, options = {})
    return INatAPIService.get("/observations/species_counts", params, options)
  end

  def self.observations_popular_field_values(params={}, options = {})
    return INatAPIService.get("/observations/popular_field_values", params, options)
  end

  def self.projects(params={}, options = {})
    return INatAPIService.get("/projects", params, options)
  end

  def self.project(id, params={}, options = {})
    return INatAPIService.get("/projects/#{id}", params, options)
  end

  def self.taxa(params={}, options={})
    return INatAPIService.get("/taxa", params, options)
  end

  def self.get_json( path, params = {}, options = {} )
    options[:retries] ||= 3
    options[:timeout] ||= INatAPIService::TIMEOUT
    options[:retry_delay] ||= 0.1
    endpoint = options[:endpoint] || INatAPIService::ENDPOINT
    url = endpoint + path
    headers = {}
    auth_user = params.delete(:authenticate)
    if auth_user && auth_user.is_a?( User )
      headers["Authorization"] = auth_user.api_token
    end
    authorization = options.delete(:authorization)
    if authorization && !headers["Authorization"]
      headers["Authorization"] = authorization
    end
    uri = URI.parse(url)
    if !params.blank? && params.is_a?(Hash)
      uri.query = URI.encode_www_form( Hash[URI.decode_www_form( uri.query || "" )].merge( params ) )
    end
    begin
      timed_out = Timeout::timeout( options[:timeout] ) do
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true if uri.scheme == "https"
        # http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        response = http.get( uri.request_uri, headers )
        if response.code == "200"
          return response.body.force_encoding( "utf-8" )
        end
      end
    rescue => e
      Rails.logger.debug "[DEBUG] INatAPIService.get_json(#{path}, #{params}, #{options[:retries]}) failed: #{e}"
    end
    if options[:retries].is_a?(Integer) && options[:retries] > 0
      retry_options = options.dup
      retry_options[:retries] -= 1
      if options[:retry_delay]
        # delay a bit before retrying
        sleep options[:retry_delay]
      end
      return INatAPIService.get_json( path, params, retry_options )
    end
    false
  end

  def self.get( path, params = {}, options = {} )
    json = get_json( path, params, options )
    return unless json
    parsed_json = JSON.parse( json ) || { }
    return parsed_json if options[:json]
    OpenStruct.new_recursive( parsed_json )
  end
end
