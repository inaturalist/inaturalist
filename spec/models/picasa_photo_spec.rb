require File.dirname(__FILE__) + '/../spec_helper.rb'

describe PicasaPhoto do
  describe "to_observation" do
    before(:all) do
      open( File.join( File.dirname(__FILE__), "..", "fixtures", "google_photos_library_photo.json" ) ) do |f|
        @fixture = JSON.parse( f.read )
      end
    end

    elastic_models( Observation, Place )
    
    it "should set description" do
      photo = PicasaPhoto.new_from_api_response( @fixture )
      obs = photo.to_observation
      expect( obs.description ).to eq @fixture["description"]
    end
  end
end
