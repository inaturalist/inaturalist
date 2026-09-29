# frozen_string_literal: true

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
      ObservationPhoto.make!( observation: observation, photo: photo )
      ModeratorAction.make!( resource: photo, action: "hide" )
      observation.reload
      expect( photo.hidden? ).to be true
      expect( observation_image_url( observation ) ).to be_nil
    end
  end

  describe "observation_place_guess" do
    it "stips tags" do
      allow_any_instance_of( ObservationsHelper ).to receive( :current_user ).and_return( nil )
      o = Observation.make!( place_guess: "Test <a>Link</a>" )
      expect( observation_place_guess( o ) ).to include "Test Link"
    end
  end
end
