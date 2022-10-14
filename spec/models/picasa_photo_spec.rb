require File.dirname(__FILE__) + '/../spec_helper.rb'

describe PicasaPhoto do
  it { is_expected.to validate_presence_of :native_photo_id }

  describe "to_observation" do
    before(:all) do
      File.open( File.join( File.dirname(__FILE__), "..", "fixtures", "google_photos_library_photo.json" ) ) do |f|
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
