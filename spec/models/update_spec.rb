require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Update, "creation" do
  it "should set resource owner" do
    o = Observation.make!
    u = Update.make!(:resource => o)
    u.resource_owner_id.should == o.user_id
  end
end

describe Update, "email_updates_to_user" do
  before(:each) { enable_elastic_indexing(Update) }
  after(:each) { disable_elastic_indexing(Update) }
  it "should deliver an email" do
    o = Observation.make!
    s = Subscription.make!(:resource => o)
    u = s.user
    update_count = u.updates.count
    without_delay do
      c = Comment.make!(:parent => o)
    end
    u.updates.count.should eq(update_count + 1)
    lambda {
      Update.email_updates_to_user(u, 10.minutes.ago, Time.now)
    }.should change(ActionMailer::Base.deliveries, :size).by(1)
  end
end

describe Update, "user_viewed_updates" do
end
