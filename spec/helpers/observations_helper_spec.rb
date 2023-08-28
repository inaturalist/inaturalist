require "spec_helper"

describe ObservationsHelper do
  let( :observation ) { Observation.make! }
  describe "observation_image_url" do
    it "should return nil if there are no photos" do
      expect( observation_image_url( observation ) ).to be_nil
    end

    it "should return the URL of the square version of the first photo" do
      photo = Photo.make!( user: observation.user )
      op = ObservationPhoto.make!( observation: observation, photo: photo )
      expect( observation_image_url( observation ) ).to eq op.photo.square_url
    end

    it "should not return hidden photos" do
      photo = Photo.make!( user: observation.user )
      op = ObservationPhoto.make!( observation: observation, photo: photo )
      ModeratorAction.make!( resource: photo, action: "hide" )
      expect( photo.hidden? ).to be true
      expect( observation_image_url( observation ) ).to be_nil
    end
  end

end
