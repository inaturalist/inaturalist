# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Trip, "updating" do
  it "should add any observations in time frame if changed"
  it "shoudl remove observations outside the time frame if changed" # or should it...
end

describe Trip, "add_taxa_from_observations" do
  let(:trip) { Trip.make! }
  it "should add taxa" do
    o = Observation.make!(:observed_on_string => (trip.start_time + 5.minutes).iso8601, :taxon => Taxon.make!, :user => trip.user)
    trip.observations.should_not be_blank
    trip.trip_taxa.count.should eq 0
    trip.add_taxa_from_observations
    trip.trip_taxa.count.should eq 1
  end

  it "should not add duplicate taxa" do
    t = Taxon.make!
    2.times do
      o = Observation.make!(:observed_on_string => (trip.start_time + 5.minutes).iso8601, :taxon => t, :user => trip.user)
    end
    trip.add_taxa_from_observations
    trip.trip_taxa.count.should eq 1
  end
end
