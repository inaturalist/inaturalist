require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ObservationPhoto, "creation" do  
  elastic_models( Observation, Identification )

  it "should update observation quality grade" do
    o = Observation.make!( observed_on_string: "2017-02-01", latitude: 1, longitude: 1 )
    expect( o.quality_grade ).to eq Observation::CASUAL
    make_observation_photo( observation: o )
    o.reload
    expect( o.quality_grade ).to eq Observation::NEEDS_ID
  end

  it "should increment observation_photos_count on the observation" do
    o = Observation.make!
    expect {
      make_observation_photo(:observation => o)
      o.reload
    }.to change(o, :observation_photos_count).by(1)
  end

  it "should touch the observation" do
    o = Observation.make!
    updated_at_was = o.updated_at
    op = make_observation_photo(:observation => o)
    o.reload
    expect( updated_at_was ).to be < o.updated_at
  end
end

describe ObservationPhoto, "destruction" do
  elastic_models( Observation )

  it "should update observation quality grade" do
    o = make_research_grade_observation
    expect( o.quality_grade ).to eq Observation::RESEARCH_GRADE
    o.observation_photos.destroy_all
    o.reload
    expect( o.quality_grade ).to eq Observation::CASUAL
  end

  it "should decrement observation_photos_count on the observation" do
    op = make_observation_photo
    o = op.observation
    expect( o.observation_photos_count ).to eq(1)
    expect {
      op.destroy
      o.reload
    }.to change(o, :observation_photos_count).by(-1)
  end
end
