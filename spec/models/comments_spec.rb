require File.expand_path("../../spec_helper", __FILE__)

describe Comment, "creation" do
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

describe Comment, "deletion" do
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

describe Comment, "flagging" do
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
