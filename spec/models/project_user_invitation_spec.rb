require 'spec_helper'

describe ProjectUserInvitation do
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
end
