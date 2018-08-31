require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ProjectInvitation, "creation" do
  it "should queue a job to generate an update for observer" do
    Delayed::Job.delete_all
    make_project_invitation
    jobs = Delayed::Job.all
    jobs.detect{|j| j.handler =~ /notify_owner_of/}.should_not be_blank
  end
end

describe ProjectInvitation, "notify_owner_of" do
  before { enable_has_subscribers }
  after { disable_has_subscribers }

  it "should generate an update for the observer" do
    pi = make_project_invitation
    lambda {
      pi.notify_owner_of(:observation)
    }.should change(UpdateAction, :count).by(1)
  end
end
