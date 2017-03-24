require File.dirname(__FILE__) + '/../spec_helper.rb'

def valid_url?(url)
  uri = URI.parse(url)
  expect( Net::HTTP.new(uri.host).request_head(uri.path+'?'+uri.query) ).to be_a Net::HTTPOK
end

describe GoogleStreetViewPhoto, "get_api_response" do
  let(:native_photo_id) {  }
  it "should return a hash of values based on its native ID, which is a url" do
    api_response = GoogleStreetViewPhoto.get_api_response("http://maps.googleapis.com/maps/api/streetview?size=600x300&location=34.579,-118.670&heading=-31&pitch=7fov=90&sensor=false")
    expect( api_response[:size] ).to eq "600x300"
  end
end

describe GoogleStreetViewPhoto, "new_from_api_response" do
  let(:native_photo_id) { "http://maps.googleapis.com/maps/api/streetview?size=600x300&location=34.579,-118.670&heading=-31&pitch=7fov=90&sensor=false" }
  let(:api_response) { GoogleStreetViewPhoto.get_api_response(native_photo_id) }
  let(:p) { GoogleStreetViewPhoto.new_from_api_response(api_response) }

  it("should set thumb url") { valid_url?(p.thumb_url) }
  it("should set square url") { valid_url?(p.square_url) }
  it("should set small url") { valid_url?(p.small_url) }
  it("should set medium url") { valid_url?(p.medium_url) }
  it("should set large url") { valid_url?(p.large_url) }
  it("should set original url") { valid_url?(p.original_url) }

  it "should set medium url with aspect ratio" do
    expect( p.medium_url ).to be =~ /size=500x250/
  end

  it "should set native_page_url to maps.google.com" do
    expect( p.native_page_url ).to be =~ /maps.google.com/
  end
  
  it "should set the license to copyright" do
    expect( p.license ).to eq Photo::COPYRIGHT
  end

  it "should set the native_realname to Google" do
    expect( p.native_realname ).to eq "Google"
  end

  it "should be valid" do
    puts "p.errors: #{p.errors.full_messages.to_sentence}" unless p.valid?
    expect( p ).to be_valid
  end
end
