# frozen_string_literal: true

require "spec_helper"

describe SubscriptionsController do
  describe "subscribe" do
    let( :user ) { UserPrivilege.make!( privilege: UserPrivilege::INTERACTION ).user }
    let( :o ) { Observation.make! }
    before do
      sign_in user
    end

    it "should create a subscription if subscribe=true" do
      post :subscribe, format: :json, params: { subscribe: true, resource_type: "Observation", resource_id: o.id }
      expect( user ).to be_subscribed_to o
    end
    it "should destroy a subscription if subscribe=false" do
      Subscription.create( resource: o, user: user )
      post :subscribe, format: :json, params: { subscribe: false, resource_type: "Observation", resource_id: o.id }
      expect( user ).not_to be_subscribed_to o
    end
    it "should do nothing if subscribe=false and no subscription exists" do
      post :subscribe, format: :json, params: { subscribe: false, resource_type: "Observation", resource_id: o.id }
      expect( user ).not_to be_subscribed_to o
    end
  end
end
