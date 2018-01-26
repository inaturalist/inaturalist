require File.dirname(__FILE__) + '/../spec_helper.rb'

describe EolPhoto, "new_from_api_response" do
  it "should set native_photo_id" do
    api_response = EolPhoto.get_api_response('7bb5cb353799e2a96a6d55ac7f4cd789')
    p = EolPhoto.new_from_api_response(api_response)
    expect(p.native_photo_id).not_to be_blank
  end

  it "should work for a fragment from a page response" do
    page = EolService.page(485229, :licenses => 'any', :images => 10, :text => 0, :videos => 0, :details => 1)
    api_response = page.at('//xmlns:dataObject[.//xmlns:mediaURL]')
    p = EolPhoto.new_from_api_response(api_response)
    expect(p.native_photo_id).not_to be_blank
  end

  it "should not set native_realname to inaturlaist" do
    page = EolService.page(455040, :licenses => 'any', :images => 10, :text => 0, :videos => 0, :details => 1)
    api_response = page.at('//xmlns:dataObject[.//xmlns:mediaURL]')
    p = EolPhoto.new_from_api_response(api_response)
    expect(p.native_realname).not_to eq "inaturalist"
  end

  it "should work for an image in the public domain" do
    p = EolPhoto.new_from_api_response(EolService.data_objects('16893553'))
    expect( p ).to be_valid
  end
end

describe "repair" do
  before(:each) { enable_elastic_indexing( Observation ) }
  after(:each) { disable_elastic_indexing( Observation ) }
  it "should not fail" do
    api_response = EolPhoto.get_api_response('7bb5cb353799e2a96a6d55ac7f4cd789')
    p = EolPhoto.new_from_api_response(api_response)
    expect {
      p.repair
    }.not_to raise_error
  end
end

describe EolPhoto, "sync" do
  before(:each) { enable_elastic_indexing( Observation ) }
  after(:each) { disable_elastic_indexing( Observation ) }
  let(:api_response) { EolPhoto.get_api_response('7bb5cb353799e2a96a6d55ac7f4cd789') }
  let(:p) { EolPhoto.new_from_api_response(api_response) }
  it "should reset native_realname" do
    orig = p.native_realname
    p.update_attribute(:native_realname, nil)
    expect(p.native_realname).to be_blank
    p.sync
    expect(p.native_realname).to eq orig
  end
end
