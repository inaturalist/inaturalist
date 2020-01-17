require 'spec_helper'

describe Message, "flagging" do
  it "should suspend the from_user if their messages have been flagged 3 times" do
    offender = UserPrivilege.make!.user
    3.times do
      m = make_message(user: offender, from_user: offender)
      m.send_message
      flag = Flag.make(flaggable: m, user: m.to_user, flag: Flag::SPAM)
      flag.save!
    end
    offender.reload
    expect( offender ).to be_suspended
  end

  it "should not destroy the flagger's copies of the messages in this thread" do
    from_user = UserPrivilege.make!.user
    to_user = UserPrivilege.make!.user
    m = make_message(from_user: from_user, to_user: to_user, user: from_user)
    m.send_message
    flag = Flag.make(flaggable: m, user: m.to_user, flag: Flag::SPAM)
    expect {
      flag.save!
    }.not_to change( Message.where(user_id: m.to_user, thread_id: m.thread_id ), :count )
  end

  it "should not destroy the spammer's copies" do
    from_user = UserPrivilege.make!.user
    to_user = UserPrivilege.make!.user
    m = make_message(from_user: from_user, to_user: to_user, user: from_user)
    m.send_message
    flag = Flag.make(flaggable: m, user: m.to_user, flag: Flag::SPAM)
    flag.save!
    expect( Message.find_by_id(m.id) ).to_not be_blank
  end
end
