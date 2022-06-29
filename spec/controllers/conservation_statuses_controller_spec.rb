# frozen_string_literal: true

require "#{File.dirname( __FILE__ )}/../spec_helper"

describe ConservationStatusesController do
  let( :taxon ) { create :taxon }
  let( :user ) { make_curator }
  before do
    sign_in user
  end
  it "should allow addition" do
    expect( taxon.conservation_statuses ).to be_blank
    post :create, params: { conservation_status: { taxon_id: taxon.id, status: "EN" } }
    taxon.reload
    expect( taxon.conservation_statuses ).not_to be_blank
  end
  it "should allow deletion" do
    conservation_status = create :conservation_status, taxon: taxon
    expect( conservation_status ).to be_persisted
    taxon.reload
    expect( taxon.conservation_statuses ).not_to be_blank
    delete :destroy, params: { id: conservation_status.id }
    taxon.reload
    expect( taxon.conservation_statuses ).to be_blank
  end
  it "should assign the current user ID as the user_id for new statuses" do
    post :create, params: { conservation_status: { taxon_id: taxon.id, status: "EN" } }
    taxon.reload
    expect( taxon.conservation_statuses.last.user ).to eq user
  end
  it "should not assign the current user ID as the user_id for other existing statuses" do
    existing = create :conservation_status, taxon: taxon
    expect( existing.user_id != user.id )
    post :create, params: { conservation_status: { taxon_id: taxon.id, status: "EN" } }
    existing.reload
    expect( existing.user_id != user.id )
  end
  it "should assign the current user ID as the updater_id for other existing statuses" do
    existing = create :conservation_status, taxon: taxon
    expect( existing&.updater_id != user.id )
    post :create, params: { conservation_status: { taxon_id: taxon.id, status: "EN" } }
    existing.reload
    expect( existing&.updater_id != user.id )
  end
end
