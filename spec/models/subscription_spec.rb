# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Subscription do

  it "knows if user subscriptions have been suspended" do
    s = Subscription.make!
    expect( Subscription.where(id: s.id).count ).to eq 1
    expect( Subscription.where(id: s.id).with_unsuspended_users.count ).to eq 1
    s.user.update_column(:subscriptions_suspended_at, Time.now)
    expect( Subscription.where(id: s.id).count ).to eq 1
    expect( Subscription.where(id: s.id).with_unsuspended_users.count ).to eq 0
  end

  describe "to place" do
    let(:user) { User.make! }
    let(:place) { make_place_with_geom }
    it "should allow multiple subscriptions for different taxa" do
      s1 = Subscription.make!(user: user, resource: place, taxon: Taxon.make!)
      s2 = Subscription.make(user: user, resource: place, taxon: Taxon.make!)
      expect(s2).to be_valid
    end

    it "should not allow multiple subscriptions for the same taxon" do
      s1 = Subscription.make!(user: user, resource: place, taxon: Taxon.make!)
      s2 = Subscription.make(user: user, resource: place, taxon: s1.taxon)
      expect(s2).to_not be_valid
    end

    it "does't allow users subscribe to North America without a taxon" do
      na = Place.make!(name: "North America")
      expect { Subscription.make!(user: user, resource: na, taxon: nil) }.
        to raise_error(ActiveRecord::RecordInvalid,
          "Validation failed: Resource cannot subscribe to North America without conditions")
    end
  end

  describe "to taxon" do
    it "should not allow multiple subscriptions to the same taxon" do
      s1 = Subscription.make!(resource: Taxon.make!)
      s2 = Subscription.make(resource: s1.resource, user: s1.user)
      expect(s2).to_not be_valid
    end
  end
end
