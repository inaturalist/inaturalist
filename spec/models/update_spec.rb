require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Update do
  before(:each) { enable_elastic_indexing(Update) }
  after(:each) { disable_elastic_indexing(Update) }
  describe "creation" do
    it "should set resource owner" do
      o = Observation.make!
      u = Update.make!(:resource => o)
      u.resource_owner_id.should == o.user_id
    end
  end

  describe "email_updates_to_user" do
    it "should deliver an email" do
      o = Observation.make!
      s = Subscription.make!(:resource => o)
      u = s.user
      update_count = u.updates.count
      without_delay do
        c = Comment.make!(:parent => o)
      end
      u.updates.count.should eq(update_count + 1)
      lambda {
        Update.email_updates_to_user(u, 10.minutes.ago, Time.now)
      }.should change(ActionMailer::Base.deliveries, :size).by(1)
    end
  end

  describe "delete_and_purge" do
    it "removes updates from ES and DB" do
      u = Update.make!
      expect(Update.count).to eq 1
      expect(Update.elastic_search.total_entries).to eq 1
      Update.delete_and_purge(id: u.id)
      expect(Update.count).to eq 0
      expect(Update.elastic_search.total_entries).to eq 0
    end
  end
end
