require File.dirname(__FILE__) + '/../spec_helper.rb'

def valid_url?(url)
  uri = URI.parse(url)
  expect( Net::HTTP.new(uri.host).request_head(uri.path+'?'+uri.query) ).to be_a Net::HTTPOK
end

describe GoogleStreetViewPhoto, "get_api_response" do
  let(:native_photo_id) {  }
  it "should return a hash of values based on its native ID, which is a url" do
    api_response = GoogleStreetViewPhoto.get_api_response("http://maps.googleapis.com/maps/api/streetview?size=600x300&location=34.579,-118.670&heading=-31&pitch=7fov=90&sensor=false&key=#{CONFIG.google.browser_api_key}")
    expect( api_response[:size] ).to eq "600x300"
  end
end

describe GoogleStreetViewPhoto, "new_from_api_response" do
  let(:native_photo_id) { "http://maps.googleapis.com/maps/api/streetview?size=600x300&location=34.579,-118.670&heading=-31&pitch=7fov=90&sensor=false&key=#{CONFIG.google.browser_api_key}" }
  let(:api_response) { GoogleStreetViewPhoto.get_api_response(native_photo_id) }
  let(:p) { GoogleStreetViewPhoto.new_from_api_response(api_response) }

  %w(thumb square medium large original).each do |size|
    it( "should set #{size} url" ) { valid_url?( p.send( "#{size}_url".to_sym ) ) }
    sleep 1
  end

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
