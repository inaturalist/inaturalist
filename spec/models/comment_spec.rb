require File.expand_path("../../spec_helper", __FILE__)

describe Comment do
  elastic_models( Observation )

  it { is_expected.to belong_to :user }

  it { is_expected.to validate_length_of(:body).is_at_least 1 }
  it { is_expected.to validate_length_of(:body).is_at_most described_class::MAX_LENGTH }
  it { is_expected.to validate_presence_of :parent }


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

    it "should not change parent_id if assigning parent_id to a UUID without a parent_type" do
      o = Observation.make!
      c = Comment.new( parent_id: o.uuid )
      expect( c.parent_id ).to be_nil
    end

    it "should assign parent when parent_id specified by UUID and parent_type assigned first" do
      o = Observation.make!
      c = Comment.new( parent_type: "Observation" )
      c.parent_id = o.uuid
      expect( c.parent_id ).to eq o.id
    end

    it "should assign parent when parent_id specified by UUID and parent_type assigned second" do
      o = Observation.make!
      c = Comment.new( parent_id: o.uuid )
      c.parent_type = "Observation"
      expect( c.parent_id ).to eq o.id
    end
  end

  describe "deletion" do
    before { enable_has_subscribers }
    after { disable_has_subscribers }

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
      expect(UpdateAction.where(resource: o).count).to eq(1)
      c.destroy
      o.reload
      expect(UpdateAction.where(resource: o).count).to eq(0)
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
    before { enable_has_subscribers }
    after { disable_has_subscribers }

    it "knows what users have been mentioned" do
      u = User.make!
      c = Comment.make!(body: "hey @#{ u.login }")
      expect( c.mentioned_users ).to eq [ u ]
    end

    it "generates mention updates" do
      u = User.make!
      c = Comment.make!(body: "hey @#{ u.login }")
      expect( UpdateAction.where(notifier: c, notification: "mention").count ).to eq 1
      expect( UpdateAction.unviewed_by_user_from_query(u.id, notifier: c) ).to eq true
    end

    it "keeps mentions up-to-date" do
      u1 = User.make!
      u2 = User.make!
      c = without_delay { Comment.make!(body: "hey") }
      expect( UpdateAction.where(notifier: c, notification: "mention").count ).to eq 0
      expect( UpdateAction.unviewed_by_user_from_query(u1.id, notifier: c) ).to eq false
      expect( UpdateAction.unviewed_by_user_from_query(u2.id, notifier: c) ).to eq false

      c.update(body: "hey @#{ u1.login }")
      expect( UpdateAction.where(notifier: c, notification: "mention").count ).to eq 1
      expect( UpdateAction.unviewed_by_user_from_query(u1.id, notifier: c) ).to eq true
      expect( UpdateAction.unviewed_by_user_from_query(u2.id, notifier: c) ).to eq false

      c.update(body: "hey @#{ u2.login }")
      expect( UpdateAction.where(notifier: c, notification: "mention").count ).to eq 1
      expect( UpdateAction.unviewed_by_user_from_query(u1.id, notifier: c) ).to eq false
      expect( UpdateAction.unviewed_by_user_from_query(u2.id, notifier: c) ).to eq true

      c.update(body: "hey @#{ u1.login }, @#{ u2.login }")
      expect( UpdateAction.where(notifier: c, notification: "mention").count ).to eq 1
      expect( UpdateAction.unviewed_by_user_from_query(u1.id, notifier: c) ).to eq true
      expect( UpdateAction.unviewed_by_user_from_query(u2.id, notifier: c) ).to eq true

      c.update(body: "hey")
      expect( UpdateAction.where(notifier: c, notification: "mention").count ).to eq 0
      expect( UpdateAction.unviewed_by_user_from_query(u1.id, notifier: c) ).to eq false
      expect( UpdateAction.unviewed_by_user_from_query(u2.id, notifier: c) ).to eq false
    end
  end

end
