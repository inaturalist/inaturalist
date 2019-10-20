require "spec_helper"

describe DarwinCore::SimpleMultimedia do
  elastic_models( Observation, Taxon )
  let(:o) { make_research_grade_observation }
  let(:p) { 
    photo = o.photos.first
    photo.update_attributes(license: Photo::CC_BY)
    DarwinCore::SimpleMultimedia.adapt(photo, observation: o)
  }
  it "should return StillImage for dwc_type" do
    expect( p.dwc_type ).to eq "StillImage"
  end
  it "should return MIME type for format" do
    expect( p.format ).to eq "image/jpeg"
  end
  it "should return original_url for identifier if available" do
    expect( p.original_url ).not_to be_blank
    expect( p.identifier ).to eq p.original_url
  end
  it "should return the medium_url if that's the best available" do
    p.update_attributes( large_url: nil, original_url: nil )
    p.reload
    expect( p.original_url ).to be_blank
    expect( p.large_url ).to be_blank
    expect( p.medium_url ).not_to be_blank
    expect( p.identifier ).to eq p.medium_url
  end
  it "should return photo page URL for references" do
    expect( p.references ).to eq p.native_page_url
  end
  # it "should return EXIF date_time_original for created"
  it "should return user name for creator" do
    expect( p.creator ).to eq p.user.name
  end
  it "should return user login for creator if name blank" do
    p.update_attributes(native_realname: nil)
    p.user.update_attributes(name: nil)
    expect( p.creator ).to eq p.user.login
  end
  it "should return iNaturalist for publisher of LocalPhoto" do
    expect( p.publisher ).to eq "iNaturalist"
  end
  
  # getting these to work would require more stubbing than I'm up for right now
  it "should return Flickr for publisher of FlickrPhoto"
  it "should return Facebook for publisher of FacebookPhoto"
  it "should return Picasa for publisher of PicasaPhoto"

  it "should return CC license URI for dwc_license" do
    expect( p.dwc_license ).to match /creativecommons.org/
  end
  it "should return user name for rightsHolder" do
    expect( p.rightsHolder ).to eq p.user.name
  end
  it "should return user login for rightsHolder if name blank" do
    p.update_attributes(native_realname: "")
    p.user.update_attributes(name: "")
    p.reload
    expect( p.native_realname ).to be_blank
    expect( p.user.name ).to be_blank
    expect( p.rightsHolder ).not_to be_blank
    expect( p.rightsHolder ).to eq p.user.login
  end
  it "should return photo ID as the catalogNumber" do
    expect( p.catalogNumber ).to eq p.id
  end
end
