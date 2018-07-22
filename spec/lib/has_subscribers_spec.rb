require "spec_helper"

describe HasSubscribers do
  before { enable_has_subscribers }
  after { disable_has_subscribers }

  # Comment uses notifies_subscribers_of and include_owner: true
  it "notifies subscribers and owners" do
    UpdateAction.delete_all
    o = Observation.make!
    s = Subscription.make!(resource: o, user: User.make!)
    c = Comment.create(parent: o, user: User.make!, body: "thebody")
    expect( UpdateAction.count ).to eq 0
    expect( UpdateAction.unviewed_by_user_from_query(o.user_id, notifier: c) ).to eq false
    expect( UpdateAction.unviewed_by_user_from_query(s.user_id, notifier: c) ).to eq false
    Delayed::Worker.new.work_off
    expect( UpdateAction.count ).to eq 1
    action = UpdateAction.where(resource_id: o.id).first
    expect( UpdateAction.unviewed_by_user_from_query(o.user_id, notifier: c) ).to eq true
    expect( UpdateAction.unviewed_by_user_from_query(s.user_id, notifier: c) ).to eq true
  end

  it "does not notify subscribers with suspended subscriptions" do
    UpdateAction.delete_all
    o = Observation.make!(user: User.make!(subscriptions_suspended_at: Time.now))
    s = Subscription.make!(resource: o, user: User.make!(subscriptions_suspended_at: Time.now))
    c = Comment.create(parent: o, user: User.make!, body: "thebody")
    expect( UpdateAction.unviewed_by_user_from_query(o.user_id, { }) ).to eq false
    expect( UpdateAction.unviewed_by_user_from_query(s.user_id, { }) ).to eq false
    expect( UpdateAction.count ).to eq 0
    Delayed::Worker.new.work_off
    expect( UpdateAction.count ).to eq 1
    # note that it DOES notify owners even if their subscriptions are suspended
    expect( UpdateAction.unviewed_by_user_from_query(o.user_id, { }) ).to eq true
    expect( UpdateAction.unviewed_by_user_from_query(s.user_id, { }) ).to eq false
  end

end
