require 'spec_helper'

describe Message do
  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to(:from_user).class_name "User" }
  it { is_expected.to belong_to(:to_user).class_name "User" }

  describe "validations" do
    let(:user) { User.make }
    let(:subject) { Message.make(user: user) }

    it { is_expected.to validate_presence_of :user }
    it { is_expected.to validate_presence_of :body }
    it { is_expected.to validate_presence_of :from_user_id }
    it { is_expected.to validate_presence_of :to_user_id }
    it { is_expected.to validate_numericality_of(:from_user_id).is_greater_than 0 }
    it { is_expected.to validate_numericality_of(:to_user_id).is_greater_than 0 }
  end


  describe "flagging" do
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

  describe "send_message" do
    let(:sender) { make_user_with_privilege( UserPrivilege::SPEECH ) }
    it "should normally make a copy for the recipient" do
      m = Message.make!( user: sender, from_user: sender )
      m.reload
      expect( m.to_user_copy ).to be_blank
      m.send_message
      m.reload
      expect( m.to_user_copy ).not_to be_blank
    end
    it "should not make a copy for the recipient if the message is spam" do
      m = Message.make!( user: sender, from_user: sender )
      m.add_flag( flag: "spam", user_id: 0 )
      m.reload
      expect( m ).to be_known_spam
      expect( m.to_user_copy ).to be_blank
      m.send_message
      m.reload
      expect( m.to_user_copy ).to be_blank
    end
    it "should not make a copy for the recipient if the sender is a spammer" do
      sender.update( spammer: true )
      m = Message.make( user: sender, from_user: sender )
      expect( m ).not_to be_valid
    end
    it "should not make a copy for the recipient if the sender is suspended" do
      sender.suspend!
      m = Message.make!( user: sender, from_user: sender )
      expect( m.to_user_copy ).to be_blank
      m.send_message
      m.reload
      expect( m.to_user_copy ).to be_blank
    end
  end
end
