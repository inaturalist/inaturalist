# -*- coding: utf-8 -*-
require File.dirname(__FILE__) + '/../spec_helper'

describe Flag, "creation" do
  elastic_models( Observation )

  it "should not allow flags that are too long" do
    f = Flag.make(
      :flag => <<-EOT
        Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod
        tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam,
        quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo
        consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse
        cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non
        proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
      EOT
    )
    expect( f ).to_not be_valid
    expect( f.errors[:flag] ).to_not be_blank
  end
  it "should not allow you to flag the same thing multiple times" do
    f1 = Flag.make!
    f2 = Flag.make( user: f1.user, flaggable: f1.flaggable, flag: f1.flag )
    expect( f2 ).not_to be_valid
    expect( f2.errors[:user_id] ).not_to be_blank
  end
  it "should allow you to flag something again if your previous flag was resolved" do
    f1 = Flag.make!
    f1.update_attributes( resolved_at: Time.now, resolver: User.make!, comment: "foo" )
    f2 = Flag.make( user: f1.user, flaggable: f1.flaggable, flag: f1.flag )
    expect( f2 ).to be_valid
    expect( f2.errors[:user_id] ).to be_blank
  end

  it "should set the flaggable content for an observation to the description" do
    o = Observation.make!( description: "some bad stuff" )
    f = Flag.make!( flaggable: o )
    expect( f.flaggable_content ).to eq o.description
  end

  it "should make flagged observations casual" do
    o = Observation.make!( observed_on_string: "2021-01-01", latitude: 1, longitude: 1 )
    expect( o.quality_grade ).to eq Observation::CASUAL
    make_observation_photo( observation: o )
    o.reload
    expect( o.quality_grade ).to eq Observation::NEEDS_ID
    Flag.make!( flaggable: o.photos.first )
    o.reload
    expect( o.quality_grade ).to eq Observation::CASUAL
  end

  [Post, Comment, Identification].each do |model|
    it "should set the flaggable content for a #{model.name} to the body" do
      r = if model == Post
        u = User.make!
        model.make!( parent: u, user: u, body: "some bad stuff" )
      else
        model.make!( body: "some bad stuff" )
      end
      f = Flag.make!( flaggable: r )
      expect( f.flaggable_content ).to eq r.body
    end
  end
end

describe Flag, "update" do
  before { enable_has_subscribers }
  after { disable_has_subscribers }

  it "should generate an update for the user" do
    t = Taxon.make!
    f = Flag.make!(flaggable: t)
    u = make_curator
    expect( UpdateAction.unviewed_by_user_from_query(f.user_id, resource: f) ).to eq false
    without_delay do
      f.update_attributes(resolver: u, comment: "foo", resolved: true)
    end
    expect( UpdateAction.unviewed_by_user_from_query(f.user_id, resource: f) ).to eq true
  end

  it "should autosubscribe the resolver" do
    t = Taxon.make!
    f = Flag.make!(flaggable: t)
    u = make_curator
    without_delay { f.update_attributes(resolver: u, comment: "foo", resolved: true) }
    expect(u.subscriptions.detect{|s| s.resource_type == "Flag" && s.resource_id == f.id}).to_not be_blank
  end

  it "should resolve even if the flaggable owner has blocked the flagger" do
    o = Observation.make!
    f = Flag.make!( flaggable: o )
    expect( f ).to be_valid
    UserBlock.make!( user: o.user, blocked_user: f.user )
    f.update_attributes( resolved: true, resolver: User.make! )
    expect( f ).to be_valid
    expect( f ).to be_resolved
  end
end

describe Flag, "destruction" do
  before { enable_has_subscribers }
  after { disable_has_subscribers }
  it "should remove the resolver's subscription" do
    t = Taxon.make!
    f = Flag.make!(flaggable: t)
    u = make_curator
    without_delay do
      f.update_attributes(resolver: u, comment: "foo", resolved: true)
    end
    f.reload
    f.destroy
    expect( u.subscriptions.detect{|s| s.resource_type == "Flag" && s.resource_id == f.id}).to be_blank
  end

  it "should remove update actions" do
    c = Comment.make!
    f = Flag.make!( flaggable: c )
    u = make_curator
    without_delay do
      f.update_attributes( resolver: u, comment: "foo", resolved: true )
    end
    f.reload
    expect( UpdateAction.unviewed_by_user_from_query( f.user_id, resource: f ) ).to eq true
    f.destroy
    expect( UpdateAction.unviewed_by_user_from_query( f.user_id, resource: f ) ).to eq false
  end
end
