require 'spec_helper'

describe ProjectUserInvitation, "creation" do
  it "should email the user" do
    lambda {
      ProjectUserInvitation.make!
    }.should change(ActionMailer::Base.deliveries, :size).by(1)
  end

  it "should create an update for the user" do
    lambda {
      ProjectUserInvitation.make!
    }.should change(Update, :count).by(1)
  end

  it "should not be possible for members of the project" do
    pu = ProjectUser.make!
    pui = ProjectUserInvitation.make(:project => pu.project, :invited_user => pu.user)
    pui.should_not be_valid
  end
end
