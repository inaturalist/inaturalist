require 'spec_helper'

describe ProjectUserInvitation, "creation" do
  it "should email the user" do
    expect {
      ProjectUserInvitation.make!
    }.to change(ActionMailer::Base.deliveries, :size).by(1)
  end

  it "should create an update for the user" do
    expect {
      ProjectUserInvitation.make!
    }.to change(Update, :count).by(1)
  end

  it "should not be possible for members of the project" do
    pu = ProjectUser.make!
    pui = ProjectUserInvitation.make(:project => pu.project, :invited_user => pu.user)
    expect( pui ).not_to be_valid
  end
end

describe ProjectUserInvitation, "deletion" do
  before(:each) { enable_elastic_indexing( Update ) }
  after(:each) { disable_elastic_indexing( Update ) }
  it "should delete updates" do
    pui = without_delay { ProjectUserInvitation.make! }
    expect( Update.where(resource: pui).count ).to eq 1
    without_delay { pui.destroy }
    expect( Update.where(resource: pui).count ).to eq 0
  end
end
