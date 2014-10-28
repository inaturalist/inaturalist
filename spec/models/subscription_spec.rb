# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Subscription, "to place" do
  let(:user) { User.make! }
  let(:place) { make_place_with_geom }
  it "should allow multiple subscriptions for different taxa" do
    s1 = Subscription.make!(:user => user, :resource => place, :taxon => Taxon.make!)
    s2 = Subscription.make(:user => user, :resource => place, :taxon => Taxon.make!)
    s2.should be_valid
  end

  it "should not allow multiple subscriptions for the same taxon" do
    p = make_place_with_geom
    s1 = Subscription.make!(:user => user, :resource => place, :taxon => Taxon.make!)
    s2 = Subscription.make(:user => user, :resource => place, :taxon => s1.taxon)
    s2.should_not be_valid
  end
end

describe Subscription, "to taxon" do
  it "should not allow multiple subscriptions to the same taxon" do
    s1 = Subscription.make!(:resource => Taxon.make!)
    s2 = Subscription.make(:resource => s1.resource, :user => s1.user)
    s2.should_not be_valid
  end
end
