# -*- coding: utf-8 -*-
require File.dirname(__FILE__) + '/../spec_helper'

describe Flag, "update" do
  it "should generate an update for the user" do
    t = Taxon.make!
    f = Flag.make!(:flaggable => t)
    u = make_curator
    without_delay do
      f.update_attributes(:resolver => u, :comment => "foo", :resolved => true)
    end
    f.user.updates.detect{|update| update.resource_type == "Flag" && update.resource_id == f.id}.should_not be_blank
  end

  it "should autosubscribe the resolver" do
    t = Taxon.make!
    f = Flag.make!(:flaggable => t)
    u = make_curator
    without_delay do
      f.update_attributes(:resolver => u, :comment => "foo", :resolved => true)
    end
    u.subscriptions.detect{|s| s.resource_type == "Flag" && s.resource_id == f.id}.should_not be_blank
  end
end

describe Flag, "destruction" do
  it "should remove the resolver's subscription" do
    t = Taxon.make!
    f = Flag.make!(:flaggable => t)
    u = make_curator
    without_delay do
      f.update_attributes(:resolver => u, :comment => "foo", :resolved => true)
    end
    f.reload
    f.destroy
    u.subscriptions.detect{|s| s.resource_type == "Flag" && s.resource_id == f.id}.should be_blank
  end
end
