# frozen_string_literal: true

require "spec_helper"

describe DarwinCore::SimpleMultimedia do
  elastic_models( Observation, Taxon )
  let( :o ) { make_research_grade_observation }
  let( :photo ) do
    first_photo = o.photos.first
    first_photo.update( license: Photo::CC_BY )
    DarwinCore::SimpleMultimedia.adapt( first_photo, observation: o )
  end
  it "should return StillImage for dwc_type" do
    expect( photo.dwc_type ).to eq "StillImage"
  end
  it "should return MIME type for format" do
    expect( photo.format ).to eq "image/jpeg"
  end
  it "should return original_url for identifier if available" do
    expect( photo.original_url ).not_to be_blank
    expect( photo.identifier ).to eq photo.original_url
  end
  it "should return photo page URL for references" do
    expect( photo.references ).to eq FakeView.photo_url( photo )
  end
  # it "should return EXIF date_time_original for created"
  it "should return user name for creator" do
    expect( photo.creator ).to eq photo.user.name
  end
  it "should return user login for creator if name blank" do
    photo.update( native_realname: nil )
    photo.user.update( name: nil )
    expect( photo.creator ).to eq photo.user.login
  end
  it "should return iNaturalist for publisher of LocalPhoto" do
    expect( photo.publisher ).to eq "iNaturalist"
  end

  # getting these to work would require more stubbing than I'm up for right now
  it "should return Flickr for publisher of FlickrPhoto"
  it "should return Picasa for publisher of PicasaPhoto"

  it "should return CC license URI for dwc_license" do
    expect( photo.dwc_license ).to match( /creativecommons.org/ )
  end
  it "should return user name for rightsHolder" do
    expect( photo.rightsHolder ).to eq photo.user.name
  end
  it "should return user login for rightsHolder if name blank" do
    photo.update( native_realname: "" )
    photo.user.update( name: "" )
    photo.reload
    expect( photo.native_realname ).to be_blank
    expect( photo.user.name ).to be_blank
    expect( photo.rightsHolder ).not_to be_blank
    expect( photo.rightsHolder ).to eq photo.user.login
  end
  it "should return photo ID as the catalogNumber" do
    expect( photo.catalogNumber ).to eq photo.id
  end
end
