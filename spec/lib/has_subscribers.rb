require "spec_helper"

describe HasSubscribers do

  # Comment uses notifies_subscribers_of and include_owner: true
  it "notifies subscribers and owners" do
    Update.delete_all
    o = Observation.make!
    s = Subscription.make!(resource: o, user: User.make!)
    c = Comment.create(parent: o, user: User.make!, body: "thebody")
    expect( Update.count ).to eq 0
    Delayed::Worker.new.work_off
    expect( Update.count ).to eq 2
    expect( Update.where(subscriber_id: o.user_id, resource_id: o.id).exists? ).to be true
    expect( Update.where(subscriber_id: s.user_id, resource_id: o.id).exists? ).to be true
  end

  it "does not notify subscribers with suspended subscriptions" do
    Update.delete_all
    o = Observation.make!(user: User.make!(subscriptions_suspended_at: Time.now))
    s = Subscription.make!(resource: o, user: User.make!(subscriptions_suspended_at: Time.now))
    c = Comment.create(parent: o, user: User.make!, body: "thebody")
    expect( Update.count ).to eq 0
    Delayed::Worker.new.work_off
    expect( Update.count ).to eq 1
    # note that it DOES notify owners even if their subscriptions are suspended
    expect( Update.where(subscriber_id: o.user_id, resource_id: o.id).exists? ).to be true
  end

end
