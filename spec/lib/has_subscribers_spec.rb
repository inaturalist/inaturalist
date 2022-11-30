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
    Delayed::Job.all.each{ |j| Delayed::Worker.new.run( j ) }
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
    Delayed::Job.all.each{ |j| Delayed::Worker.new.run( j ) }
    expect( UpdateAction.count ).to eq 1
    # note that it DOES notify owners even if their subscriptions are suspended
    expect( UpdateAction.unviewed_by_user_from_query(o.user_id, { }) ).to eq true
    expect( UpdateAction.unviewed_by_user_from_query(s.user_id, { }) ).to eq false
  end

  describe "notify_subscribers_of" do
    it "skips subscribables that do not include HasSubscribers" do
      s = Site.make!
      expect {
        without_delay{ Post.make!( parent: s ) }
      }.to_not raise_error
    end
  end

  describe "place subscriptions with taxon" do
    let( :user ) { User.make! }
    let( :genus ) { Taxon.make!( rank: Taxon::GENUS ) }
    let( :species ) { Taxon.make!( rank: Taxon::SPECIES, parent: genus ) }
    let( :place ) { make_place_with_geom( admin_level: Place::STATE_LEVEL ) }

    it "notifies subscribers of descendants of the taxon" do
      s = Subscription.make!(resource: place, user: user, taxon: genus )
      expect( UpdateAction.unviewed_by_user_from_query(user.id, { }) ).to eq false
      expect( UpdateAction.count ).to eq 0
      # make an observation of a species within the subscribed genus
      make_research_grade_observation(
        latitude: place.latitude, longitude: place.longitude, taxon: species)
      Delayed::Job.all.each{ |j| Delayed::Worker.new.run( j ) }
      expect( UpdateAction.unviewed_by_user_from_query(user.id, { }) ).to eq true
      expect( UpdateAction.count ).to be > 1
    end

    it "notifies subscribers of the taxon" do
      s = Subscription.make!(resource: place, user: user, taxon: genus )
      expect( UpdateAction.unviewed_by_user_from_query(user.id, { }) ).to eq false
      expect( UpdateAction.count ).to eq 0
      # make an observation o the subscribed genus
      make_research_grade_observation(
        latitude: place.latitude, longitude: place.longitude, taxon: genus)
      Delayed::Job.all.each{ |j| Delayed::Worker.new.run( j ) }
      expect( UpdateAction.unviewed_by_user_from_query(user.id, { }) ).to eq true
      expect( UpdateAction.count ).to be > 1
    end

  end

end
