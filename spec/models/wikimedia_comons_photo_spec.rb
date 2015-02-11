require File.dirname(__FILE__) + '/../spec_helper.rb'

describe WikimediaCommonsPhoto, "search_wikimedia_for_taxon" do
  it "should work" do
    photos = WikimediaCommonsPhoto.search_wikimedia_for_taxon('Homo sapiens')
    photos.should_not be_blank
  end
end

describe WikimediaCommonsPhoto, "new_from_api_response" do
  it "should retrieve author when available" do
    r = WikimediaCommonsPhoto.get_api_response('Dendronotus_iris.jpg')
    wp = WikimediaCommonsPhoto.new_from_api_response(r)
    wp.native_realname.should == 'Daniel Hershman'
  end

  it "should retrieve author from license block" do
    r = WikimediaCommonsPhoto.get_api_response('Cercidium_floridum_flower.jpg')
    wp = WikimediaCommonsPhoto.new_from_api_response(r)
    wp.native_realname.should == 'Stan Shebs'
  end

  it "should retrieve license" do
    r = WikimediaCommonsPhoto.get_api_response('Timema_californicum_(Santa_Lucia_Range,_California).jpg')
    wp = WikimediaCommonsPhoto.new_from_api_response(r)
    wp.license.should == Photo::CC_BY_SA
  end

  it "should recognize public domain images" do
    [
      'Doriopsilla_albopunctata.jpg',
      'Ischnocybe_plicata_-_Cook_%26_Loomis_1928.jpg'
    ].each do |filename|
      r = WikimediaCommonsPhoto.get_api_response(filename)
      wp = WikimediaCommonsPhoto.new_from_api_response(r)
      wp.license.should eq Photo::PD
    end
  end

  it "should recognize GFDL images" do
    r = WikimediaCommonsPhoto.get_api_response('Circus_maurus.jpg')
    wp = WikimediaCommonsPhoto.new_from_api_response(r)
    wp.license.should == Photo::GFDL
  end

  it "should not retrieve sizes that don't exist" do
    r = WikimediaCommonsPhoto.get_api_response('Doriopsilla_albopunctata.jpg')
    wp = WikimediaCommonsPhoto.new_from_api_response(r)
    wp.large_url.should be_blank
  end

  it "should credit photos without a clear author as anonymous" do
    r = WikimediaCommonsPhoto.get_api_response('Cervus_elaphus_1_strakonice_beentree_2005.jpg')
    wp = WikimediaCommonsPhoto.new_from_api_response(r)
    wp.native_realname.should == 'anonymous'
  end

  it "should have square and thumb urls even if the photo is tiny" do
    r = WikimediaCommonsPhoto.get_api_response('Altamira_Yellowthroat_(Geothlypis_flavovelata)_male.jpg')
    wp = WikimediaCommonsPhoto.new_from_api_response(r)
    wp.square_url.should_not be_blank
    wp.thumb_url.should_not be_blank
  end
end
