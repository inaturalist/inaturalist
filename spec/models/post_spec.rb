require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Post, "creation" do
  it "should not generate an activity stream if it's a draft" do
    friendship = Friendship.make
    user, friend = [friendship.user, friendship.friend]
    expect {
      Post.make(:draft, :user => friend)
    }.to_not change(Delayed::Job, :count)
  end
end
