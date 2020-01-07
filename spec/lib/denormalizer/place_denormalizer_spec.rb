require File.expand_path("../../../spec_helper", __FILE__)

describe 'PlaceDenormalizer' do

  elastic_models( Identification )

  before(:all) do
    @place = make_place_with_geom
    @observation = Observation.make!(latitude: @place.latitude,
      longitude: @place.longitude)
  end

  it 'should denormalize properly' do
    PlaceDenormalizer.truncate
    expect(ObservationsPlace.count).to be 0
    PlaceDenormalizer.denormalize
    expect(ObservationsPlace.count).to be 1
    expect(ObservationsPlace.exists?(observation_id: @observation.id,
      place_id: @place.id)).to be true
  end

  it 'should truncate the table' do
    PlaceDenormalizer.truncate
    expect(ObservationsPlace.count).to be 0
    PlaceDenormalizer.denormalize
    expect(ObservationsPlace.count).to be 1
    PlaceDenormalizer.truncate
    expect(ObservationsPlace.count).to be 0
  end

end
