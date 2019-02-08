class GooglePhotosApi
  attr_accessor :token
  attr_accessor :refresh_token
  def initialize( token, options = {} )
    self.token = token
    self.refresh_token = options[:refresh_token]
  end

  def media_items( options = {} )
    # response = RestClient.get(
    #   "https://photoslibrary.googleapis.com/v1/mediaItems?#{options.to_query}",
    #   Authorization: "Bearer #{token}"
    # )
    # JSON.parse( response.body )
    get( "mediaItems", options )
  end

  def media_item( id )
    get( "mediaItems/#{id}" )
  end

  def albums
    get( "albums" )
  end

  def search( options = {} )
    post( "mediaItems:search", options )
  end

  private
  def get( endpoint, params = {} )
    url = "https://photoslibrary.googleapis.com/v1/#{endpoint}?#{params.to_query}"
    Rails.logger.debug "[DEBUG] [GooglePhotosApi] getting #{url}"
    response = RestClient.get( url, Authorization: "Bearer #{token}" )
    JSON.parse( response.body )
  end

  def post( endpoint, json = nil )
    url = "https://photoslibrary.googleapis.com/v1/#{endpoint}"
    Rails.logger.debug "[DEBUG] [GooglePhotosApi] POST #{url}, body: #{json}"
    response = RestClient.post( url, json.to_json, { Authorization: "Bearer #{token}", content_type: :json, accept: :json } )
    Rails.logger.debug "[DEBUG] [GooglePhotosApi] response.headers: #{response.headers}"
    JSON.parse( response.body )
  end
end
