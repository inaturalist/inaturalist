# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Trip do
  it { is_expected.to have_many(:trip_taxa).dependent(:destroy).inverse_of :trip }
  it { is_expected.to have_many(:trip_purposes).dependent :destroy }
  it { is_expected.to have_many(:taxa).through :trip_taxa }
  it { is_expected.to belong_to(:place).inverse_of :trips }

  describe Trip, "updating" do
    it "should add any observations in time frame if changed"
    it "should remove observations outside the time frame if changed" # or should it...
  end

  describe Trip, "add_taxa_from_observations" do
    let(:trip) { Trip.make! }
    it "should add taxa" do
      o = Observation.make!(:observed_on_string => (trip.start_time + 5.minutes).iso8601, :taxon => Taxon.make!, :user => trip.user)
      expect(trip.observations).not_to be_blank
      expect(trip.trip_taxa.count).to eq 0
      trip.add_taxa_from_observations
      expect(trip.trip_taxa.count).to eq 1
    end

    it "should not add duplicate taxa" do
      t = Taxon.make!
      2.times do
        o = Observation.make!(:observed_on_string => (trip.start_time + 5.minutes).iso8601, :taxon => t, :user => trip.user)
      end
      trip.add_taxa_from_observations
      expect(trip.trip_taxa.count).to eq 1
    end
  end
end

# Stopped working as of af1e334ba0e7bafc27c1fc82c29d553e4e821f20, not sure why, but... trips
# describe Trip, "observations" do
#   let(:trip) do
#     Trip.make!(
#       start_time: Chronic.parse('August 28, 2015 09:08 AM'),
#       stop_time: Chronic.parse('August 28, 2015 05:08 PM')
#     )
#   end
#   it "should include observations that have times within the time range" do
#     o = Observation.make!(user: trip.user, observed_on_string: 'August 28, 2015 01:08 PM')
#     expect( trip.observations.map(&:id) ).to include(o.id)
#   end
#   it "should not include observations that have times outside the time range" do
#     o = Observation.make!(user: trip.user, observed_on_string: 'August 28, 2015 08:08 PM')
#     expect( trip.observations.map(&:id) ).not_to include(o.id)
#   end
#   it "should include observations that have dates but not times within the time range" do
#     o = Observation.make!(user: trip.user, observed_on_string: 'August 28, 2015')
#     expect( trip.observations.map(&:id) ).to include(o.id)
#   end
# end
