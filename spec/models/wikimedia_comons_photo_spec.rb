require File.dirname(__FILE__) + '/../spec_helper.rb'

describe WikimediaCommonsPhoto, "search_wikimedia_for_taxon" do
  it "should work" do
    photos = WikimediaCommonsPhoto.search_wikimedia_for_taxon('Homo sapiens')
    expect(photos).not_to be_blank
  end
end

describe WikimediaCommonsPhoto, "new_from_api_response" do
  it "should retrieve author when available" do
    r = WikimediaCommonsPhoto.get_api_response('Dendronotus_iris.jpg')
    wp = WikimediaCommonsPhoto.new_from_api_response(r)
    expect(wp.native_realname).to eq 'Daniel Hershman'
  end

  it "should retrieve author from license block" do
    r = WikimediaCommonsPhoto.get_api_response('Cercidium_floridum_flower.jpg')
    wp = WikimediaCommonsPhoto.new_from_api_response(r)
    expect(wp.native_realname).to eq 'Stan Shebs'
  end

  it "should retrieve license" do
    r = WikimediaCommonsPhoto.get_api_response('Timema_californicum_(Santa_Lucia_Range,_California).jpg')
    wp = WikimediaCommonsPhoto.new_from_api_response(r)
    expect(wp.license).to eq Photo::CC_BY_SA
  end

  it "should recognize public domain images" do
    [
      'Doriopsilla_albopunctata.jpg',
      'Ischnocybe_plicata_-_Cook_%26_Loomis_1928.jpg'
    ].each do |filename|
      r = WikimediaCommonsPhoto.get_api_response(filename)
      wp = WikimediaCommonsPhoto.new_from_api_response(r)
      expect(wp.license).to eq Photo::PD
    end
  end

  it "should recognize GFDL images" do
    r = WikimediaCommonsPhoto.get_api_response('Circus_maurus.jpg')
    wp = WikimediaCommonsPhoto.new_from_api_response(r)
    expect(wp.license).to eq Photo::GFDL
  end

  it "should not retrieve sizes that don't exist" do
    r = WikimediaCommonsPhoto.get_api_response('Doriopsilla_albopunctata.jpg')
    wp = WikimediaCommonsPhoto.new_from_api_response(r)
    expect(wp.large_url).to be_blank
  end

  it "should credit photos without a clear author as anonymous" do
    r = WikimediaCommonsPhoto.get_api_response('Cervus_elaphus_1_strakonice_beentree_2005.jpg')
    wp = WikimediaCommonsPhoto.new_from_api_response(r)
    expect(wp.native_realname).to eq 'anonymous'
  end

  it "should have square and thumb urls even if the photo is tiny" do
    r = WikimediaCommonsPhoto.get_api_response('Altamira_Yellowthroat_(Geothlypis_flavovelata)_male.jpg')
    wp = WikimediaCommonsPhoto.new_from_api_response(r)
    expect(wp.square_url).not_to be_blank
    expect(wp.thumb_url).not_to be_blank
  end
end
