require File.dirname(__FILE__) + '/../spec_helper.rb'

describe PicasaPhoto do
  describe "to_observation" do
    before(:all) do
      f = open(File.dirname(__FILE__) + '/../fixtures/picasa_photo.xml', 'r')
      @xml = f.read
      f.close
      @nxml = Nokogiri::XML(@xml)
    end
    
    it "should set coordinates" do
      @nxml.at('//gml:pos').should_not be_blank
      plat, plon = @nxml.at('//gml:pos').inner_text.split
      api_response = RubyPicasa::Photo.new(@xml)
      photo = PicasaPhoto.new(:user => User.make)
      photo.api_response = api_response
      obs = photo.to_observation
      obs.latitude.to_f.should == plat.to_f
      obs.longitude.to_f.should == plon.to_f
    end
  end
end