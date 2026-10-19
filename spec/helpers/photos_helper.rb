# frozen_string_literal: true

require "spec_helper"

describe PhotosHelper, type: :helper do
  def sign_in_as( user )
    allow( helper ).to receive( :logged_in? ).and_return( user.present? )
    allow( helper ).to receive( :current_user ).and_return( user )
  end

  describe "metadata_table_rows" do
    let( :photo_lat ) { 37.5 }
    let( :photo_lng ) { -122.5 }
    let!( :photo ) do
      photo = LocalPhoto.make( user: User.make! )
      photo.file = File.open( File.join( Rails.root, "spec", "fixtures", "files", "cuthona_abronia-tagged.png" ) )
      photo.extract_metadata
      photo.save
      photo
    end

    let!( :observation ) do
      observation = photo.to_observation
      observation.save
      photo.reload
      observation
    end

    it "includes GPS metadata for photos associated with unobscured observations when logged in" do
      sign_in_as( User.make! )

      expect( photo.metadata[:gps_latitude] ).to be_within( 0.1 ).of( photo_lat )
      expect( photo.metadata[:gps_longitude] ).to be_within( 0.1 ).of( photo_lng )
      expect( observation.latitude ).to eq photo.metadata[:gps_latitude].to_d
      expect( observation.longitude ).to eq photo.metadata[:gps_longitude].to_d

      metadata = helper.metadata_table_rows( photo )
      expect( metadata["GPS latitude"] ).to eq( photo.metadata[:gps_latitude] )
      expect( metadata["GPS longitude"] ).to eq( photo.metadata[:gps_longitude] )
    end

    it "does not include GPS metadata for photos associated with private observations when logged in" do
      sign_in_as( User.make! )

      photo.observations.first.update( geoprivacy: "private" )

      metadata = helper.metadata_table_rows( photo )
      expect( metadata ).not_to have_key( "GPS latitude" )
      expect( metadata ).not_to have_key( "GPS longitude" )
    end

    it "does include GPS metadata for photos associated with private observations when logged in " \
      "as the photographer" do
      sign_in_as( photo.user )

      photo.observations.first.update( geoprivacy: "private" )

      metadata = helper.metadata_table_rows( photo )
      expect( metadata["GPS latitude"] ).to be_within( 0.1 ).of( photo_lat )
      expect( metadata["GPS longitude"] ).to be_within( 0.1 ).of( photo_lng )
    end

    it "does not include GPS metadata for photos associated with obscured observations when logged in" do
      sign_in_as( User.make! )

      photo.observations.first.update( geoprivacy: "obscured" )

      metadata = helper.metadata_table_rows( photo )
      expect( metadata ).not_to have_key( "GPS latitude" )
      expect( metadata ).not_to have_key( "GPS longitude" )
    end

    it "does include GPS metadata for photos associated with obscured observations when logged in " \
      "as the photographer" do
      sign_in_as( photo.user )

      photo.observations.first.update( geoprivacy: "obscured" )

      metadata = helper.metadata_table_rows( photo )
      expect( metadata["GPS latitude"] ).to be_within( 0.1 ).of( photo_lat )
      expect( metadata["GPS longitude"] ).to be_within( 0.1 ).of( photo_lng )
    end

    it "does not include GPS metadata for photos associated with obscured taxon geoprivacy when logged in" do
      sign_in_as( User.make! )

      taxon = make_threatened_taxon
      Identification.make!( taxon: taxon, observation: observation )
      observation.reload
      expect( observation.taxon_geoprivacy ).to eq Observation::OBSCURED

      metadata = helper.metadata_table_rows( photo )
      expect( metadata ).not_to have_key( "GPS latitude" )
      expect( metadata ).not_to have_key( "GPS longitude" )
    end

    it "does include GPS metadata for photos associated with obscured taxon geoprivacy when logged in " \
      "as the photographer" do
      sign_in_as( photo.user )

      taxon = make_threatened_taxon
      Identification.make!( taxon: taxon, observation: observation )
      observation.reload
      expect( observation.taxon_geoprivacy ).to eq Observation::OBSCURED

      metadata = helper.metadata_table_rows( photo )
      expect( metadata["GPS latitude"] ).to be_within( 0.1 ).of( photo_lat )
      expect( metadata["GPS longitude"] ).to be_within( 0.1 ).of( photo_lng )
    end

    it "does not include GPS metadata for photos associated with unobscured coordinates when logged out" do
      sign_in_as( nil )

      metadata = helper.metadata_table_rows( photo )
      expect( metadata ).not_to have_key( "GPS latitude" )
      expect( metadata ).not_to have_key( "GPS longitude" )
    end

    it "does not include GPS metadata for photos associated with no observations when logged in" do
      sign_in_as( User.make! )

      photo.observations.destroy_all
      metadata = helper.metadata_table_rows( photo )
      expect( metadata ).not_to have_key( "GPS latitude" )
      expect( metadata ).not_to have_key( "GPS longitude" )
    end

    it "does include GPS metadata for photos associated with no observations when logged in " \
      "as the photographer" do
      sign_in_as( photo.user )

      photo.observations.destroy_all
      metadata = helper.metadata_table_rows( photo )
      expect( metadata["GPS latitude"] ).to be_within( 0.1 ).of( photo_lat )
      expect( metadata["GPS longitude"] ).to be_within( 0.1 ).of( photo_lng )
    end
  end
end
