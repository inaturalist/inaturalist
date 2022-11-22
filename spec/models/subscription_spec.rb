# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Subscription do
  it { is_expected.to belong_to(:resource).inverse_of :update_subscriptions }
  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to :taxon }

  it { is_expected.to validate_presence_of :resource }
  it { is_expected.to validate_presence_of :user }
  it do
    is_expected.to validate_uniqueness_of(:user_id).scoped_to(:resource_type, :resource_id, :taxon_id)
                                                   .with_message "has already subscribed to this resource"
  end

  describe "to place" do
    let(:user) { User.make! }

    it "does't allow users subscribe to North America without a taxon" do
      na = make_place_with_geom(name: "North America")
      expect { Subscription.make!(user: user, resource: na, taxon: nil) }.
        to raise_error(ActiveRecord::RecordInvalid,
          "Validation failed: Resource cannot subscribe to North America without conditions")
    end
  end
end
