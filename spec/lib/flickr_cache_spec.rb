require "spec_helper"

describe FlickrCache,
  disabled: (CONFIG.flickr.shared_secret == "09af09af09af09af") do

  before(:all) do
    @flickr = Flickr.new( Flickr.api_key, Flickr.shared_secret )
  end

  it "creates the endpoint" do
    expect(ApiEndpoint.count).to eq 0
    FlickrCache.fetch(@flickr, "photos", "search", tags: "animals")
    expect(ApiEndpoint.count).to eq 1
    endpoint = ApiEndpoint.first
    expect(endpoint.title).to eq "Flickr"
    expect(endpoint.description).to eq nil
    expect(endpoint.documentation_url).to eq "http://www.flickr.com/services/api/"
    expect(endpoint.base_url).to eq "https://api.flickr.com/services/rest?"
    expect(endpoint.cache_hours).to eq 720
  end

  it "caches the result" do
    expect(ApiEndpointCache.count).to eq 0
    fetched = FlickrCache.fetch(@flickr, "photos", "search", tags: "animals")
    expect(ApiEndpointCache.count).to eq 1
    cache = ApiEndpointCache.first
    expect(cache.request_url).to eq "flickr.photos.search({\"tags\":\"animals\"})"
    expect(cache.cached?).to be true
  end

  #
  # kueda 2017-11-17 Not sure whatt this was supposed to test. Seems like
  # getSizes with params like tags: 'animals' should fail b/c a photo ID wasn't
  # specified, and failed requests don't seem to get cached
  # 
  # it "cached calls to any method" do
  #   expect(ApiEndpointCache.count).to eq 0
  #   # expect(@flickr.photos).to receive(:getSizes).and_return(@flickr_response)
  #   fetched = FlickrCache.fetch(@flickr, "photos", "getSizes", tags: "animals")
  #   expect(ApiEndpointCache.count).to eq 1
  #   cache = ApiEndpointCache.first
  #   expect(cache.request_url).to eq "flickr.photos.getSizes({\"tags\":\"animals\"})"
  #   # expect(cache.response).to eq "{\"table\":{\"url\":\"some image URL\"}}"
  #   expect(cache.cached?).to be true
  #   # expect(fetched).to be @flickr_response
  # end

end

# These examples stub the FlickrCache.request seam so they never touch the
# network and don't need Flickr credentials, unlike the examples above
describe FlickrCache do
  def fetch
    FlickrCache.fetch( nil, "photos", "search", tags: "animals" )
  end

  describe "throttle protection" do
    it "records endpoint throttling when Flickr returns an HTTP throttle error" do
      allow( FlickrCache ).to receive( :request ).and_raise(
        Flickr::OAuthClient::FailedResponse.new( "Too many requests" )
      )
      expect( fetch ).to be_nil
      cache = ApiEndpointCache.last
      expect( cache.throttled? ).to be true
      expect( cache.success ).to be false
      expect( FlickrCache.api_endpoint.recently_throttled? ).to be true
    end

    it "records endpoint throttling when a Flickr API failure indicates throttling" do
      allow( FlickrCache ).to receive( :request ).and_raise(
        Flickr::FailedResponse.new( "You have been making too many requests", "0", "flickr.photos.search" )
      )
      expect( fetch ).to be_nil
      expect( ApiEndpointCache.last.throttled? ).to be true
      expect( FlickrCache.api_endpoint.recently_throttled? ).to be true
    end

    it "records other Flickr API failures without throttling" do
      allow( FlickrCache ).to receive( :request ).and_raise(
        Flickr::FailedResponse.new( "Photo not found", "1", "flickr.photos.getSizes" )
      )
      expect( fetch ).to be_nil
      cache = ApiEndpointCache.last
      expect( cache.success ).to be false
      expect( cache.throttled? ).to be false
      expect( FlickrCache.api_endpoint.recently_throttled? ).to be false
    end

    it "does not call Flickr while the endpoint was recently throttled" do
      FlickrCache.api_endpoint.update( last_throttled_at: 1.minute.ago )
      expect( FlickrCache ).not_to receive( :request )
      expect( fetch ).to be_nil
    end

    it "returns nothing for a throttled response cached within the retry window" do
      ApiEndpointCache.make!(
        api_endpoint: FlickrCache.api_endpoint,
        request_url: "flickr.photos.search({\"tags\":\"animals\"})",
        status_code: ApiEndpointCache::THROTTLED_STATUS_CODE,
        success: false,
        response: "Too many requests",
        request_began_at: 1.minute.ago,
        request_completed_at: 1.minute.ago
      )
      expect( FlickrCache ).not_to receive( :request )
      expect( fetch ).to be_nil
    end
  end

  describe "fetch" do
    it "caches and returns successful responses" do
      allow( FlickrCache ).to receive( :request ).and_return( [{ "id" => 1 }].to_json )
      fetched = fetch
      expect( fetched.first.id ).to eq 1
      cache = ApiEndpointCache.last
      expect( cache.success ).to be true
      expect( cache.throttled? ).to be false
    end
  end
end
