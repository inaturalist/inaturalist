# frozen_string_literal: true

require "spec_helper"

describe Message do
  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to( :from_user ).class_name "User" }
  it { is_expected.to belong_to( :to_user ).class_name "User" }

  describe "validations" do
    let( :user ) { User.make }
    let( :subject ) { Message.make( user: user ) }

    it { is_expected.to validate_presence_of :user }
    it { is_expected.to validate_presence_of :body }
    it { is_expected.to validate_presence_of :from_user_id }
    it { is_expected.to validate_presence_of :to_user_id }
    it { is_expected.to validate_numericality_of( :from_user_id ).is_greater_than 0 }
    it { is_expected.to validate_numericality_of( :to_user_id ).is_greater_than 0 }
  end

  describe "flagging" do
    let( :serial_spammer ) do
      offender = UserPrivilege.make!( privilege: UserPrivilege::SPEECH ).user
      UserPrivilege.make!( user: offender, privilege: UserPrivilege::INTERACTION )
      3.times do
        m = make_message( user: offender, from_user: offender )
        m.send_message
        flag = Flag.make( flaggable: m, user: m.to_user, flag: Flag::SPAM )
        flag.save!
      end
      offender.reload
      offender
    end

    it "should suspend the from_user if their messages have been flagged 3 times" do
      expect( serial_spammer ).to be_suspended
    end

    it "should not destroy the flagger's copies of the messages in this thread" do
      from_user = UserPrivilege.make!( privilege: UserPrivilege::SPEECH ).user
      UserPrivilege.make!( user: from_user, privilege: UserPrivilege::INTERACTION )
      to_user = UserPrivilege.make!( privilege: UserPrivilege::SPEECH ).user
      m = make_message( from_user: from_user, to_user: to_user, user: from_user )
      m.send_message
      flag = Flag.make( flaggable: m, user: m.to_user, flag: Flag::SPAM )
      expect do
        flag.save!
      end.not_to change( Message.where( user_id: m.to_user, thread_id: m.thread_id ), :count )
    end

    it "should not destroy the spammer's copies" do
      from_user = UserPrivilege.make!( privilege: UserPrivilege::SPEECH ).user
      UserPrivilege.make!( user: from_user, privilege: UserPrivilege::INTERACTION )
      to_user = UserPrivilege.make!( privilege: UserPrivilege::SPEECH ).user
      m = make_message( from_user: from_user, to_user: to_user, user: from_user )
      m.send_message
      flag = Flag.make( flaggable: m, user: m.to_user, flag: Flag::SPAM )
      flag.save!
      expect( Message.find_by_id( m.id ) ).to_not be_blank
    end

    it "should resend unsent message when spam flag resolved" do
      # Expect serial spammer's first message to be spam
      msg = serial_spammer.messages.outbox.first
      expect( msg ).to be_known_spam

      # Unsuspend the spammer; their message should still be considered spam
      serial_spammer.unsuspend!
      Delayed::Worker.new.work_off
      msg.reload
      expect( msg ).to be_known_spam

      # Resolve flags on all the spammer's messages
      curator = make_curator
      msg.flags.each do | flag |
        flag.resolved = true
        flag.resolver = curator
        flag.resolved_at = Time.now
        flag.save!
      end
      Delayed::Worker.new.work_off
      msg.reload

      # Flags should be resolved so the message is no longer considered spam
      expect( msg ).not_to be_known_spam

      # and the message should have been resent
      expect( msg ).to be_sent
    end
  end

  describe "send_message" do
    let( :sender ) do
      sender = make_user_with_privilege( UserPrivilege::SPEECH )
      UserPrivilege.make!( user: sender, privilege: UserPrivilege::INTERACTION )
      sender
    end
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
    it "should set sent_at" do
      m = create :message, user: sender
      expect( m.sent_at ).to be_blank
      m.send_message
      expect( m.sent_at ).not_to be_blank
    end
    it "should not set sent_at if sender is suspended" do
      m = create :message, user: sender
      sender.suspend!
      expect( m.sent_at ).to be_blank
      m.send_message
      expect( m.sent_at ).to be_blank
    end
  end

  describe "requires_privilege" do
    let( :user ) { User.make! }

    it "allows creation with speech and interaction" do
      UserPrivilege.make!( user: user, privilege: UserPrivilege::SPEECH )
      UserPrivilege.make!( user: user, privilege: UserPrivilege::INTERACTION )
      m = Message.make( user: user, from_user: user )
      expect( m ).to be_valid
    end

    it "disallows creation without speech" do
      UserPrivilege.make!( user: user, privilege: UserPrivilege::INTERACTION )
      m = Message.make( user: user, from_user: user )
      expect( m ).not_to be_valid
      expect( m.errors.any? {| e | e.type == :requires_privilege_speech } ).to be true
    end

    # TODO: uncomment to strictly enforce email confirmation for interaction
    it "disallows creation without interaction" do
      pending( "fully enabled email confirmation for interaction" )
      UserPrivilege.make!( user: user, privilege: UserPrivilege::SPEECH )
      m = Message.make( user: user, from_user: user )
      expect( m ).not_to be_valid
      expect( m.errors.any? {| e | e.type == :requires_privilege_interaction } ).to be true
    end

    it "allows creation without speech or interaction for replies" do
      existing_user = UserPrivilege.make!( privilege: UserPrivilege::SPEECH ).user
      UserPrivilege.make!( user: existing_user, privilege: UserPrivilege::INTERACTION )
      m1 = Message.make!( user: existing_user, from_user: existing_user, to_user: user )
      m2 = Message.make( user: user, from_user: user, to_user: m1.from_user, thread_id: m1.id )
      expect( m2 ).to be_valid
    end
  end
end
