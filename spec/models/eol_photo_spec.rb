require File.dirname(__FILE__) + '/../spec_helper.rb'

describe EolPhoto, "new_from_api_response" do
  it "should set native_photo_id" do
    api_response = EolPhoto.get_api_response( 5246083 )
    p = EolPhoto.new_from_api_response(api_response)
    expect(p.native_photo_id).not_to be_blank
  end

  it "should work for a fragment from a page response" do
    page = EolService.page( 485229, licenses: "all", images_per_page: 10, text_per_page: 0, videos_per_page: 0, details: true )
    api_response = page.at('//dataObject[.//mediaURL]')
    p = EolPhoto.new_from_api_response(api_response)
    expect(p.native_photo_id).not_to be_blank
  end

  it "should not set native_realname to inaturalist" do
    page = EolService.page( 455040, licenses: "all", images_per_page: 10, text_per_page: 0, videos_per_page: 0, details: true )
    api_response = page.at('//dataObject[.//mediaURL]')
    p = EolPhoto.new_from_api_response(api_response)
    expect(p.native_realname).not_to eq "inaturalist"
  end

  it "should work for an image in the public domain" do
    p = EolPhoto.new_from_api_response( EolService.data_objects( 5246083 ) )
    expect( p ).to be_valid
  end
end

describe EolPhoto, "repair", disabled: ENV["TRAVIS_CI"] do
  elastic_models( Observation )
  it "should not fail" do
    api_response = EolPhoto.get_api_response( 5246083 )
    p = EolPhoto.new_from_api_response(api_response)
    expect {
      p.repair
    }.not_to raise_error
  end
end

describe EolPhoto, "sync", disabled: ENV["TRAVIS_CI"] do
  elastic_models( Observation )
  let(:api_response) { EolPhoto.get_api_response( 5246083 ) }
  let(:p) { EolPhoto.new_from_api_response(api_response) }
  it "should reset native_realname" do
    orig = p.native_realname
    p.update_attribute(:native_realname, nil)
    expect(p.native_realname).to be_blank
    p.sync
    expect(p.native_realname).to eq orig
  end
end
