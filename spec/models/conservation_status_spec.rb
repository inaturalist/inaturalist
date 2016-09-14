# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ConservationStatus, "creation" do
  before(:each) do
    @taxon = Taxon.make!(:rank => Taxon::SPECIES)
    enable_elastic_indexing( Observation )
  end
  after(:each) { disable_elastic_indexing( Observation ) }

  it "should obscure observations of taxon" do
    o = Observation.make!(:taxon => @taxon, :latitude => 1, :longitude => 1)
    expect(o).not_to be_coordinates_obscured
    cs = without_delay {ConservationStatus.make!(:taxon => @taxon)}
    @taxon.reload
    expect(@taxon).to be_threatened
    o.reload
    expect(o).to be_coordinates_obscured
  end

  it "should obscure observations of a taxon in place" do
    p = make_place_with_geom
    o = Observation.make!(:taxon => @taxon, :latitude => p.latitude, :longitude => p.longitude)
    expect(o).not_to be_coordinates_obscured
    cs = without_delay {ConservationStatus.make!(:taxon => @taxon, :place => p)}
    o.reload
    expect(o).to be_coordinates_obscured
  end

  it "should not obscure observations of taxon outside place" do
    p = make_place_with_geom
    o = Observation.make!(:taxon => @taxon, :latitude => -1*p.latitude, :longitude => p.longitude)
    expect(o).not_to be_coordinates_obscured
    cs = without_delay {ConservationStatus.make!(:taxon => @taxon, :place => p)}
    o.reload
    expect(o).not_to be_coordinates_obscured
  end

  it "should have geoprivacy obscured by default" do
    expect( ConservationStatus.make!.geoprivacy ).to eq Observation::OBSCURED
  end
  it "should not allow blank string geoprivacy" do
    expect( ConservationStatus.make!(geoprivacy: '').geoprivacy ).to be_nil
  end
end

describe ConservationStatus, "saving" do
  it "should should set taxon conservation_status" do
    t = Taxon.make!
    expect(t.conservation_status).to be_blank
    cs = without_delay {ConservationStatus.make!(:taxon => t)}
    expect(cs.iucn).not_to be_blank
    t.reload
    expect(t.conservation_status).to eq(cs.iucn)
  end

  it "should nilify taxon conservation_status if no other global statuses" do
    cs = without_delay {ConservationStatus.make!}
    t = cs.taxon
    expect(t.conservation_status).not_to be_blank
    without_delay {cs.update_attributes(:iucn => Taxon::IUCN_LEAST_CONCERN)}
    t.reload
    expect(t.conservation_status).to be < Taxon::IUCN_NEAR_THREATENED
  end

  it "should should not set taxon conservation_status if not the highest status" do
    t = Taxon.make!
    cs1 = without_delay {ConservationStatus.make!(:iucn => Taxon::IUCN_ENDANGERED, :taxon => t, :authority => "foo")}
    cs2 = without_delay {ConservationStatus.make!(:iucn => Taxon::IUCN_LEAST_CONCERN, :taxon => t, :authority => "bar")}
    t.reload
    expect(t.conservation_status).to eq(cs1.iucn)
  end

  it "should should not set taxon conservation_status if not global" do
    t = Taxon.make!
    p = Place.make!
    cs = ConservationStatus.make!(:taxon => t, :place => p)
    t.reload
    expect(t.conservation_status).to be_blank
  end
end

describe ConservationStatus, "deletion" do
  before(:each) do
    @taxon = Taxon.make!(:rank => Taxon::SPECIES)
  end

  it "should reassess observations of taxon" do
    cs = without_delay { ConservationStatus.make!(:taxon => @taxon) }
    o = Observation.make!(:taxon => @taxon, :latitude => 1, :longitude => 1)
    expect(o).to be_coordinates_obscured
    cs.destroy
    Delayed::Worker.new.work_off
    @taxon.reload
    expect(@taxon).not_to be_threatened
    o.reload
    expect(o).not_to be_coordinates_obscured
  end
end

describe ConservationStatus, "updating geoprivacy" do
  before(:each) do
    @taxon = Taxon.make!(:rank => Taxon::SPECIES)
    @cs = ConservationStatus.make!(:taxon => @taxon)
  end

  it "should obscure observations of taxon" do
    o = Observation.make!(:taxon => @taxon, :latitude => 1, :longitude => 1)
    expect(o).to be_coordinates_obscured
    without_delay {@cs.update_attributes(:geoprivacy => Observation::PRIVATE)}
    o.reload
    expect(o.latitude).to be_blank
  end

  it "should unobscure observations of taxon" do
    o = Observation.make!(:taxon => @taxon, :latitude => 1, :longitude => 1)
    expect(o).to be_coordinates_obscured
    @cs.update_attributes(:geoprivacy => Observation::PRIVATE)
    Delayed::Worker.new.work_off
    o.reload
    expect(o.latitude).to be_blank
    @cs.update_attributes(:geoprivacy => Observation::OPEN)
    Delayed::Worker.new.work_off
    o.reload
    expect(o.latitude).not_to be_blank
    expect(o.private_latitude).to be_blank
  end

  it "should change geom for observations of taxon" do
    o = Observation.make!(:taxon => @taxon, :latitude => 1, :longitude => 1)
    lat = o.latitude
    geom_lat = o.geom.y
    @cs.update_attributes(:geoprivacy => Observation::OPEN)
    expect(@taxon.conservation_statuses.count).to eq 1
    Delayed::Worker.new.work_off
    o.reload
    expect(o.latitude.to_f).not_to eq lat.to_f
    expect(o.geom.y).not_to eq geom_lat
  end

  it "should obscure observations of taxon in place" do
    p = make_place_with_geom
    o = Observation.make!(:taxon => @taxon, :latitude => p.latitude, :longitude => p.longitude)
    expect(o).to be_coordinates_obscured
    without_delay {@cs.update_attributes(:geoprivacy => Observation::PRIVATE)}
    o.reload
    expect(o.latitude).to be_blank
  end

  it "should not obscure observations of taxon outside place" do
    p = make_place_with_geom
    o = Observation.make!(:taxon => @taxon, :latitude => -1*p.latitude, :longitude => p.longitude)
    expect(o).to be_coordinates_obscured
    without_delay {@cs.update_attributes(:geoprivacy => Observation::PRIVATE, :place => p)}
    o.reload
    expect(o.latitude).not_to be_blank
  end
end
