require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Post, "creation" do
  it "should not generate jobs if it's a draft" do
    friendship = Friendship.make
    user, friend = [friendship.user, friendship.friend]
    expect {
      Post.make(:draft, :user => friend)
    }.to_not change(Delayed::Job, :count)
  end

  it "should not generate an update for the owner" do
    u = User.make!
    post = without_delay {Post.make!(:user => u, :parent => u)}
    Update.where(:notifier_type => "Post", :notifier_id => post.id, :subscriber_id => post.user_id).first.should be_blank
  end
end

describe Post, "creation for project" do
  it "should generate an update for the owner" do
    p = Project.make!
    u = p.user
    post = without_delay {Post.make!(:user => u, :parent => p)}
    Update.where(:notifier_type => "Post", :notifier_id => post.id, :subscriber_id => post.user_id).first.should_not be_blank
  end
end

describe Post, "creation for user" do
  it "should generate updates for followers" do
    f = Friendship.make!
    post = without_delay { Post.make!(:parent => f.friend) }
    Update.where(:notifier_type => "Post", :notifier_id => post.id, :subscriber_id => f.user_id).first.should_not be_blank
  end
end
