require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ObservationPhoto, "creation" do
  it "should update observation quality_grade" do
    o = Observation.make(:taxon => Taxon.make, :latitude => 1, :longitude => 1, :observed_on_string => "yesterday")
    i = Identification.make(:observation => o, :taxon => o.taxon)
    o.quality_grade.should == Observation::CASUAL_GRADE
    o.photos << LocalPhoto.make(:user => o.user)
    o.reload
    o.quality_grade.should == Observation::RESEARCH_GRADE
  end
  
  it "should update user_id on photo" do
    p = Photo.make(:user => nil)
    p.user.should be_blank
    o = Observation.make
    op = ObservationPhoto.make(:photo => p, :observation => o)
    p.reload
    p.user_id.should == o.user_id
  end
end

describe ObservationPhoto, "destruction" do
  it "should update observation quality_grade" do
    o = Observation.make(:taxon => Taxon.make, :latitude => 1, :longitude => 1, :observed_on_string => "yesterday")
    i = Identification.make(:observation => o, :taxon => o.taxon)
    o.photos << LocalPhoto.make(:user => o.user)
    o.reload
    o.quality_grade.should == Observation::RESEARCH_GRADE
    o.observation_photos.each(&:destroy)
    o.reload
    o.quality_grade.should == Observation::CASUAL_GRADE
  end
end