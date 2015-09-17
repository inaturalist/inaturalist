require File.expand_path("../../spec_helper", __FILE__)

describe Comment do
  describe "creation" do
    it "should increment a counter cache on the parent if the column exists" do
      o = Observation.make!
      c = Comment.make!(:parent => o)
      o.reload
      expect(o.comments_count).to eq(1)
    end

    it "should touch the parent" do
      o = Observation.make!
      stamp = o.updated_at
      c = Comment.make!(:parent => o)
      o.reload
      expect(o.updated_at).to be > stamp
    end
  end

  describe "deletion" do
    before(:each) { enable_elastic_indexing(Update) }
    after(:each) { disable_elastic_indexing(Update) }

    it "should decrement a counter cache on the parent if the column exists" do
      o = Observation.make!
      c = Comment.make!(:parent => o)
      o.reload
      expect(o.comments_count).to eq(1)
      c.destroy
      o.reload
      expect(o.comments_count).to eq(0)
    end

    it "should delete an associated update" do
      o = Observation.make!
      s = Subscription.make!(:resource => o)
      c = Comment.make(:parent => o)
      without_delay { c.save }
      expect(Update.where(:subscriber_id => s.user_id, :resource_type => 'Observation', :resource_id => o.id).count).to eq(1)
      c.destroy
      o.reload
      expect(Update.where(:subscriber_id => s.user_id, :resource_type => 'Observation', :resource_id => o.id).count).to eq(0)
    end
  end

  describe "flagging" do
    it "should suspend the commenter if their comments have been flagged 3 times" do
      offender = User.make!
      3.times do
        c = Comment.make!(:user => offender)
        flag = Flag.make(:flaggable => c, :flag => Flag::SPAM)
        flag.save!
      end
      offender.reload
      expect(offender).to be_suspended
    end
  end

  describe "mentions" do
    it "knows what users have been mentioned" do
      u = User.make!
      c = Comment.make!(body: "hey @#{ u.login }")
      expect( c.mentioned_users ).to eq [ u ]
    end

    it "generates mention updates" do
      u = User.make!
      c = without_delay { Comment.make!(body: "hey @#{ u.login }") }
      expect( Update.where(notifier: c).mention.count ).to eq 1
      expect( Update.where(notifier: c).mention.first.subscriber ).to eq u
    end

    it "keeps mentions up-to-date" do
      u1 = User.make!
      u2 = User.make!
      c = without_delay { Comment.make!(body: "hey") }
      expect( Update.where(notifier: c).mention.count ).to eq 0
      without_delay { c.update_attributes(body: "hey @#{ u1.login }") }
      expect( Update.where(notifier: c).mention.count ).to eq 1
      expect( Update.where(notifier: c).mention.first.subscriber ).to eq u1
      without_delay { c.update_attributes(body: "hey @#{ u2.login }") }
      expect( Update.where(notifier: c).mention.count ).to eq 1
      expect( Update.where(notifier: c).mention.first.subscriber ).to eq u2
      without_delay { c.update_attributes(body: "hey @#{ u1.login }, @#{ u2.login }") }
      expect( Update.where(notifier: c).mention.count ).to eq 2
      expect( Update.where(notifier: c).mention.map(&:subscriber) ).to eq [ u1, u2 ]
      without_delay { c.update_attributes(body: "hey") }
      expect( Update.where(notifier: c).mention.count ).to eq 0
    end
  end

end
