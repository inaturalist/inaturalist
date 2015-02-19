require File.dirname(__FILE__) + '/../spec_helper.rb'

describe EolPhoto, "new_from_api_response" do
  it "should set native_photo_id" do
    api_response = EolPhoto.get_api_response('7bb5cb353799e2a96a6d55ac7f4cd789')
    p = EolPhoto.new_from_api_response(api_response)
    p.native_photo_id.should_not be_blank
  end

  it "should work for a fragment from a page response" do
    page = EolService.page(485229, :licenses => 'any', :images => 10, :text => 0, :videos => 0, :details => 1)
    api_response = page.at('//xmlns:dataObject[.//xmlns:mediaURL]')
    p = EolPhoto.new_from_api_response(api_response)
    p.native_photo_id.should_not be_blank
  end

  it "should not set native_realname to inaturlaist" do
    page = EolService.page(455040, :licenses => 'any', :images => 10, :text => 0, :videos => 0, :details => 1)
    api_response = page.at('//xmlns:dataObject[.//xmlns:mediaURL]')
    p = EolPhoto.new_from_api_response(api_response)
    p.native_realname.should_not eq "inaturalist"
  end
end

describe EolPhoto, "sync" do
  let(:api_response) { EolPhoto.get_api_response('7bb5cb353799e2a96a6d55ac7f4cd789') }
  let(:p) { EolPhoto.new_from_api_response(api_response) }
  it "should reset native_realname" do
    orig = p.native_realname
    p.update_attribute(:native_realname, nil)
    p.native_realname.should be_blank
    p.sync
    p.native_realname.should eq orig
  end
end
