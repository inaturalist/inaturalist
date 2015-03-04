require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Update, "creation" do
  it "should set resource owner" do
    o = Observation.make!
    u = Update.make!(:resource => o)
    u.resource_owner_id.should == o.user_id
  end
end

describe Update, "email_updates_to_user" do
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
  it "should queue job to delete old updates" do
    u = User.make!
    old_update = Update.make!(:created_at => 7.months.ago, :subscriber => u)
    new_update = Update.make!(:subscriber => u)
    stamp = Time.now
    Update.user_viewed_updates([new_update])
    jobs = Delayed::Job.where("created_at >= ?", stamp)
    jobs.select{|j| j.handler =~ /Update.*sweep_for_user.*#{u.id}/m}.size.should eq(1)
  end

  it "should only queue job to delete old updates once" do
    u = User.make!
    old_update = Update.make!(:created_at => 7.months.ago, :subscriber => u)
    new_update = Update.make!(:subscriber => u)
    stamp = Time.now
    Update.user_viewed_updates([new_update])
    Update.user_viewed_updates([new_update])
    jobs = Delayed::Job.where("created_at >= ?", stamp)
    jobs.select{|j| j.handler =~ /Update.*sweep_for_user.*#{u.id}/m}.size.should eq(1)
  end
  
  it "should delete updates made over 6 months ago" do
    old_update = Update.make!(:created_at => 7.months.ago)
    new_update = Update.make!(:subscriber => old_update.subscriber)
    without_delay do
      Update.user_viewed_updates([new_update])
    end
    Update.find_by_id(old_update.id).should be_blank
  end

  it "should delete activity updates that aren't the last update on the subscribables viewed" do
    old_update = Update.make!(:notification => "activity")
    new_update = Update.make!(:notification => "activity", :subscriber => old_update.subscriber, :resource => old_update.resource)
    without_delay do
      Update.user_viewed_updates([new_update])
    end
    Update.find_by_id(old_update.id).should be_blank
    Update.find_by_id(new_update.id).should_not be_blank
  end
end
