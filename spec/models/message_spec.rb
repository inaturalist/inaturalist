require 'spec_helper'

describe Message, "flagging" do
  it "should suspend the from_user if their messages have been flagged 3 times" do
    offender = User.make!
    3.times do
      m = make_message(:user => offender, :from_user => offender)
      m.send_message
      flag = Flag.make(:flaggable => m, :user => m.to_user, :flag => Flag::SPAM)
      flag.save!
    end
    offender.reload
    offender.should be_suspended
  end

  it "should destroy the flagger's copies of the messages in this thread" do
    m = make_message
    m.send_message
    flag = Flag.make(:flaggable => m, :user => m.to_user, :flag => Flag::SPAM)
    flag.save!
    Message.where(:user_id => m.to_user, :thread_id => m.thread_id).count.should eq(0)
  end
end
