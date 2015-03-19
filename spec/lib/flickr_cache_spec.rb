require "spec_helper"

describe FlickrCache do

  before(:all) do
    @flickr_response = OpenStruct.new(url: "some image URL")
    @flickraw = flickr
  end

  it "creates the endpoint" do
    expect(ApiEndpoint.count).to eq 0
    expect(@flickraw.photos).to receive(:search).and_return(@flickr_response)
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
    expect(@flickraw.photos).to receive(:search).and_return(@flickr_response)
    fetched = FlickrCache.fetch(@flickraw, "photos", "search", tags: "animals")
    expect(ApiEndpointCache.count).to eq 1
    cache = ApiEndpointCache.first
    expect(cache.request_url).to eq "flickr.photos.search({\"tags\":\"animals\"})"
    expect(cache.response).to eq "{\"table\":{\"url\":\"some image URL\"}}"
    expect(cache.cached?).to be true
    expect(fetched).to be @flickr_response
  end

  it "cached calls to any method" do
    expect(ApiEndpointCache.count).to eq 0
    expect(@flickraw.photos).to receive(:getSizes).and_return(@flickr_response)
    fetched = FlickrCache.fetch(@flickraw, "photos", "getSizes", tags: "animals")
    expect(ApiEndpointCache.count).to eq 1
    cache = ApiEndpointCache.first
    expect(cache.request_url).to eq "flickr.photos.getSizes({\"tags\":\"animals\"})"
    expect(cache.response).to eq "{\"table\":{\"url\":\"some image URL\"}}"
    expect(cache.cached?).to be true
    expect(fetched).to be @flickr_response
  end

end
