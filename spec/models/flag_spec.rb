# -*- coding: utf-8 -*-
require File.dirname(__FILE__) + '/../spec_helper'

describe Flag, "creation" do
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
end

describe Flag, "update" do
  it "should generate an update for the user" do
    t = Taxon.make!
    f = Flag.make!(flaggable: t)
    u = make_curator
    without_delay do
      f.update_attributes(resolver: u, comment: "foo", resolved: true)
    end
    expect( UpdateAction.joins(:update_subscribers).
      where(resource: f).where("update_subscribers.subscriber_id = ?", f.user_id).count ).to eq 1
  end

  it "should autosubscribe the resolver" do
    t = Taxon.make!
    f = Flag.make!(flaggable: t)
    u = make_curator
    without_delay { f.update_attributes(resolver: u, comment: "foo", resolved: true) }
    expect(u.subscriptions.detect{|s| s.resource_type == "Flag" && s.resource_id == f.id}).to_not be_blank
  end
end

describe Flag, "destruction" do
  before(:each) { enable_elastic_indexing(UpdateAction) }
  after(:each) { disable_elastic_indexing(UpdateAction) }
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
end
