require File.dirname(__FILE__) + '/../spec_helper.rb'

describe UpdateAction do
  before(:each) { enable_elastic_indexing(UpdateAction) }
  after(:each) { disable_elastic_indexing(UpdateAction) }
  describe "creation" do
    it "should set resource owner" do
      o = Observation.make!
      u = UpdateAction.make!(resource: o)
      expect( u.resource_owner_id ).to eq o.user_id
    end
  end

  describe "email_updates_to_user" do
    it "should deliver an email" do
      o = Observation.make!
      s = Subscription.make!(resource: o)
      u = s.user
      update_count = u.update_subscribers.count
      without_delay do
        c = Comment.make!(parent: o)
      end
      expect( u.update_subscribers.count ).to eq (update_count + 1)
      expect {
        UpdateAction.email_updates_to_user(u, 10.minutes.ago, Time.now)
      }.to change(ActionMailer::Base.deliveries, :size).by(1)
    end
  end

  describe "delete_and_purge" do
    it "removes updates from ES and DB" do
      u = UpdateAction.make!
      expect(UpdateAction.count).to eq 1
      expect(UpdateAction.elastic_search.total_entries).to eq 1
      UpdateAction.delete_and_purge(id: u.id)
      expect(UpdateAction.count).to eq 0
      expect(UpdateAction.elastic_search.total_entries).to eq 0
    end
  end
end
