require File.expand_path("../../../spec_helper", __FILE__)

describe 'PlaceDenormalizer' do

  before(:all) do
    @place = make_place_with_geom
    @observation = Observation.make!(:latitude => @place.latitude,
      :longitude => @place.longitude)
  end

  it 'should denormalize properly' do
    PlaceDenormalizer.truncate
    ObservationsPlace.count.should == 0
    PlaceDenormalizer.denormalize
    ObservationsPlace.count.should == 1
    ObservationsPlace.exists?(observation_id: @observation.id,
      place_id: @place.id).should be_true
  end

  it 'should truncate the table' do
    PlaceDenormalizer.truncate
    ObservationsPlace.count.should == 0
    PlaceDenormalizer.denormalize
    ObservationsPlace.count.should == 1
    PlaceDenormalizer.truncate
    ObservationsPlace.count.should == 0
  end

end
