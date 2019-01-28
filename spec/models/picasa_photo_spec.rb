require File.dirname(__FILE__) + '/../spec_helper.rb'

describe PicasaPhoto do
  describe "to_observation" do
    before(:all) do
      f = open(File.dirname(__FILE__) + '/../fixtures/picasa_photo.xml', 'r')
      @xml = f.read
      f.close
      @nxml = Nokogiri::XML(@xml)
    end

    before(:each) { enable_elastic_indexing( Observation, Place ) }
    after(:each) { disable_elastic_indexing( Observation, Place ) }
    
    it "should set coordinates" do
      expect(@nxml.at('//gml:pos')).not_to be_blank
      plat, plon = @nxml.at('//gml:pos').inner_text.split
      api_response = RubyPicasa::Photo.new(@xml)
      photo = PicasaPhoto.new(:user => User.make)
      photo.api_response = api_response
      obs = photo.to_observation
      expect(obs.latitude.to_f).to eq plat.to_f
      expect(obs.longitude.to_f).to eq plon.to_f
    end
  end
end
