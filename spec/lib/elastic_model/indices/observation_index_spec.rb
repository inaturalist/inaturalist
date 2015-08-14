require "spec_helper"

describe "Observation Index" do
  before( :all ) do
    @starting_time_zone = Time.zone
    Time.zone = ActiveSupport::TimeZone["Samoa"]
  end
  after( :all ) { Time.zone = @starting_time_zone }

  it "as_indexed_json should return a hash" do
    o = Observation.make!
    json = o.as_indexed_json
    expect( json ).to be_a Hash
  end

  it "sets location based on private coordinates if exist" do
    o = Observation.make!(latitude: 3.0, longitude: 4.0)
    o.update_attributes(private_latitude: 1.0, private_longitude: 2.0)
    json = o.as_indexed_json
    expect( json[:location] ).to eq "1.0,2.0"
  end

  it "sets location based on public coordinates if there are no private" do
    o = Observation.make!(latitude: 3.0, longitude: 4.0)
    json = o.as_indexed_json
    expect( json[:location] ).to eq "3.0,4.0"
  end

  it "indexes created_at based on observation time zone" do
    o = Observation.make!(created_at: "2014-12-31 20:00:00 -0800")
    json = o.as_indexed_json
    expect( json[:created_at].day ).to eq 31
    expect( json[:created_at].month ).to eq 12
    expect( json[:created_at].year ).to eq 2014
  end

  it "indexes created_at_details based on observation time zone" do
    o = Observation.make!(created_at: "2014-12-31 20:00:00 -0800")
    json = o.as_indexed_json
    expect( json[:created_at_details][:day] ).to eq 31
    expect( json[:created_at_details][:month] ).to eq 12
    expect( json[:created_at_details][:year] ).to eq 2014
  end

  it "sorts photos by position and ID" do
    o = Observation.make!(latitude: 3.0, longitude: 4.0)
    p3 = LocalPhoto.make!
    p1 = LocalPhoto.make!
    p2 = LocalPhoto.make!
    p4 = LocalPhoto.make!
    p5 = LocalPhoto.make!
    ObservationPhoto.make!(photo: p1, observation: o, position: 1)
    ObservationPhoto.make!(photo: p2, observation: o, position: 2)
    ObservationPhoto.make!(photo: p3, observation: o, position: 3)
    # these without a position will be last in order of creation
    ObservationPhoto.make!(photo: p4, observation: o)
    ObservationPhoto.make!(photo: p5, observation: o)
    json = o.as_indexed_json
    expect( json[:photos][0][:id] ).to eq p1.id
    expect( json[:photos][1][:id] ).to eq p2.id
    expect( json[:photos][2][:id] ).to eq p3.id
    expect( json[:photos][3][:id] ).to eq p4.id
    expect( json[:photos][4][:id] ).to eq p5.id
  end

  it "uses private_latitude/longitude to create private_geojson" do
    o = Observation.make!
    o.update_columns(private_latitude: 3.0, private_longitude: 4.0, private_geom: nil)
    o.reload
    expect( o.private_geom ).to be nil
    json = o.as_indexed_json
    expect( json[:private_geojson][:coordinates] ).to eq [4.0, 3.0]
  end
end
