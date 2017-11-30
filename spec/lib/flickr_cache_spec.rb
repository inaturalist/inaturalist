require "spec_helper"

describe FlickrCache,
  disabled: (CONFIG.flickr.shared_secret == "09af09af09af09af") do

  before(:all) do
    @flickraw = flickr
  end

  it "creates the endpoint" do
    expect(ApiEndpoint.count).to eq 0
    FlickrCache.fetch(@flickraw, "photos", "search", tags: "animals")
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
    fetched = FlickrCache.fetch(@flickraw, "photos", "search", tags: "animals")
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
  #   # expect(@flickraw.photos).to receive(:getSizes).and_return(@flickr_response)
  #   fetched = FlickrCache.fetch(@flickraw, "photos", "getSizes", tags: "animals")
  #   expect(ApiEndpointCache.count).to eq 1
  #   cache = ApiEndpointCache.first
  #   expect(cache.request_url).to eq "flickr.photos.getSizes({\"tags\":\"animals\"})"
  #   # expect(cache.response).to eq "{\"table\":{\"url\":\"some image URL\"}}"
  #   expect(cache.cached?).to be true
  #   # expect(fetched).to be @flickr_response
  # end

end
