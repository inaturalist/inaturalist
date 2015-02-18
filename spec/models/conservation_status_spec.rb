# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ConservationStatus, "creation" do
  before(:each) do
    @taxon = Taxon.make!(:rank => Taxon::SPECIES)
  end

  it "should obscure observations of taxon" do
    o = Observation.make!(:taxon => @taxon, :latitude => 1, :longitude => 1)
    o.should_not be_coordinates_obscured
    cs = without_delay {ConservationStatus.make!(:taxon => @taxon)}
    @taxon.reload
    @taxon.should be_threatened
    o.reload
    o.should be_coordinates_obscured
  end

  it "should obscure observations of a taxon in place" do
    p = make_place_with_geom
    o = Observation.make!(:taxon => @taxon, :latitude => p.latitude, :longitude => p.longitude)
    o.should_not be_coordinates_obscured
    cs = without_delay {ConservationStatus.make!(:taxon => @taxon, :place => p)}
    o.reload
    o.should be_coordinates_obscured
  end

  it "should not obscure observations of taxon outside place" do
    p = make_place_with_geom
    o = Observation.make!(:taxon => @taxon, :latitude => -1*p.latitude, :longitude => p.longitude)
    o.should_not be_coordinates_obscured
    cs = without_delay {ConservationStatus.make!(:taxon => @taxon, :place => p)}
    o.reload
    o.should_not be_coordinates_obscured
  end
end

describe ConservationStatus, "saving" do
  it "should should set taxon conservation_status" do
    t = Taxon.make!
    t.conservation_status.should be_blank
    cs = without_delay {ConservationStatus.make!(:taxon => t)}
    cs.iucn.should_not be_blank
    t.reload
    t.conservation_status.should eq(cs.iucn)
  end

  it "should nilify taxon conservation_status if no other global statuses" do
    cs = without_delay {ConservationStatus.make!}
    t = cs.taxon
    t.conservation_status.should_not be_blank
    without_delay {cs.update_attributes(:iucn => Taxon::IUCN_LEAST_CONCERN)}
    t.reload
    t.conservation_status.should be < Taxon::IUCN_NEAR_THREATENED
  end

  it "should should not set taxon conservation_status if not the highest status" do
    t = Taxon.make!
    cs1 = without_delay {ConservationStatus.make!(:iucn => Taxon::IUCN_ENDANGERED, :taxon => t, :authority => "foo")}
    cs2 = without_delay {ConservationStatus.make!(:iucn => Taxon::IUCN_LEAST_CONCERN, :taxon => t, :authority => "bar")}
    t.reload
    t.conservation_status.should eq(cs1.iucn)
  end

  it "should should not set taxon conservation_status if not global" do
    t = Taxon.make!
    p = Place.make!
    cs = ConservationStatus.make!(:taxon => t, :place => p)
    t.reload
    t.conservation_status.should be_blank
  end
end

describe ConservationStatus, "deletion" do
  before(:each) do
    @taxon = Taxon.make!(:rank => Taxon::SPECIES)
  end

  it "should reassess observations of taxon" do
    cs = without_delay { ConservationStatus.make!(:taxon => @taxon) }
    o = Observation.make!(:taxon => @taxon, :latitude => 1, :longitude => 1)
    o.should be_coordinates_obscured
    cs.destroy
    Delayed::Worker.new.work_off
    @taxon.reload
    @taxon.should_not be_threatened
    o.reload
    o.should_not be_coordinates_obscured
  end
end

describe ConservationStatus, "updating geoprivacy" do
  before(:each) do
    @taxon = Taxon.make!(:rank => Taxon::SPECIES)
    @cs = ConservationStatus.make!(:taxon => @taxon)
  end

  it "should obscure observations of taxon" do
    o = Observation.make!(:taxon => @taxon, :latitude => 1, :longitude => 1)
    o.should be_coordinates_obscured
    without_delay {@cs.update_attributes(:geoprivacy => Observation::PRIVATE)}
    o.reload
    o.latitude.should be_blank
  end

  it "should unobscure observations of taxon" do
    o = Observation.make!(:taxon => @taxon, :latitude => 1, :longitude => 1)
    o.should be_coordinates_obscured
    without_delay {@cs.update_attributes(:geoprivacy => Observation::PRIVATE)}
    o.reload
    o.latitude.should be_blank
    without_delay {@cs.update_attributes(:geoprivacy => Observation::OPEN)}
    o.reload
    o.latitude.should_not be_blank
    o.private_latitude.should be_blank
  end

  it "should change geom for observations of taxon" do
    o = Observation.make!(:taxon => @taxon, :latitude => 1, :longitude => 1)
    lat = o.latitude
    geom_lat = o.geom.y
    @cs.update_attributes(:geoprivacy => Observation::OPEN)
    @taxon.conservation_statuses.count.should eq 1
    Delayed::Worker.new.work_off
    o.reload
    o.latitude.to_f.should_not eq lat.to_f
    o.geom.y.should_not eq geom_lat
  end

  it "should obscure observations of taxon in place" do
    p = make_place_with_geom
    o = Observation.make!(:taxon => @taxon, :latitude => p.latitude, :longitude => p.longitude)
    o.should be_coordinates_obscured
    without_delay {@cs.update_attributes(:geoprivacy => Observation::PRIVATE)}
    o.reload
    o.latitude.should be_blank
  end

  it "should not obscure observations of taxon outside place" do
    p = make_place_with_geom
    o = Observation.make!(:taxon => @taxon, :latitude => -1*p.latitude, :longitude => p.longitude)
    o.should be_coordinates_obscured
    without_delay {@cs.update_attributes(:geoprivacy => Observation::PRIVATE, :place => p)}
    o.reload
    o.latitude.should_not be_blank
  end
end
