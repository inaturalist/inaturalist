require "spec_helper"

describe DarwinCore::Occurrence do
  it "should strip newlines from occurrenceRemarks" do
    o = Observation.make!( description: "here's a line\nand here's another\r\nand yet another\r" )
    expect( DarwinCore::Occurrence.adapt( o ).occurrenceRemarks ).to eq "here's a line and here's another and yet another"
  end

  it "should include stateProvince when available" do
    p = make_place_with_geom( admin_level: Place::STATE_LEVEL )
    o = Observation.make!( latitude: p.latitude, longitude: p.longitude )
    expect( DarwinCore::Occurrence.adapt( o ).stateProvince ).to eq p.name
  end
end
