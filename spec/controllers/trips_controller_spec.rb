# frozen_string_literal: true

require "spec_helper"

describe TripsController, "show" do
  render_views

  let( :user ) { User.make! }
  let( :trip ) { Trip.make!( user: user, radius: nil ) }

  before do
    stub_const( "Taxon::LIFE", Taxon.make!( name: "Life", rank: Taxon::STATEOFMATTER ) )
    Observation.make!( user: user, observed_on_string: 4.hours.ago.iso8601 )
  end

  it "renders a trip with no radius" do
    get :show, params: { id: trip.id }
    expect( response ).to be_successful
  end

  describe "for a responsive-global member" do
    before do
      user.update_column( :test_groups, "responsive-global" )
      sign_in user
    end

    it "renders a trip with no radius" do
      get :show, params: { id: trip.id }
      expect( request.variant ).to include( :responsive )
      expect( response ).to be_successful
    end

    it "offers the responsive test group toggle" do
      get :show, params: { id: trip.id }
      expect( assigns( :test_group_toggle ) ).to eq "responsive-global"
    end
  end
end
