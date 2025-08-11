# -*- coding: utf-8 -*-
require File.dirname(__FILE__) + '/../spec_helper'

describe UserParent do
  it { is_expected.to belong_to(:user).inverse_of :user_parent }
  it { is_expected.to belong_to(:parent_user).inverse_of(:parentages).class_name "User" }

  it { is_expected.to validate_presence_of :name }
  it { is_expected.to validate_presence_of :child_name }
  it { is_expected.to validate_presence_of :user }

  describe "creation" do
    it "should not trigger the delivery of any emails" do
      deliveries = Devise.mailer.deliveries.size
      # The blueprint makes an active user that was a created a little while ago
      # by default, so we need to make a new user here
      user = User.make
      up = UserParent.make!(
        user: User.new(
          login: user.login,
          email: user.email,
          birthday: 9.years.ago.to_date.to_s,
          password: "foofoo",
          password_confirmation: "foofoo"
        )
      )
      expect( up ).not_to be_donor
      Delayed::Worker.new.work_off
      expect( Devise.mailer.deliveries.size ).to eq deliveries
    end

    it "should not allow an email that belongs to another user that is not the parent user" do
      existing_user = User.make!
      up = UserParent.make( email: existing_user.email )
      expect( up ).not_to be_valid
      expect( up.errors[:email] ).not_to be_blank
    end
    it "should allow an email that belongs to another user that is the parent user" do
      existing_user = User.make!
      up = UserParent.make!( email: existing_user.email, parent_user: existing_user )
      expect( up ).to be_valid
    end
  end

  describe "update" do
    it "should allow the donorbox_donor_id to be set even if a non-parent user exists with the same email address" do
      up = UserParent.make!
      User.make!( email: up.email )
      up.update( donorbox_donor_id: 1 )
      expect( up ).to be_valid
    end

    it "should allow the virtuous_donor_contact_id to be set even if a non-parent user exists with the same email address" do
      up = UserParent.make!
      User.make!( email: up.email )
      up.update( virtuous_donor_contact_id: 1 )
      expect( up ).to be_valid
    end
  end

  describe "donorbox_donor_id" do
    it "gets set on create based on the parent_user" do
      up = UserParent.make!( parent_user: User.make!( donorbox_donor_id: 1 ) )
      expect( up.donorbox_donor_id ).not_to be_blank
      expect( up.donorbox_donor_id ).to eq up.parent_user.donorbox_donor_id
    end

    it "delivers an email to child when set on update" do
      up = create( :user_parent )
      emails_to_child_before = ActionMailer::Base.deliveries.select {| m | m.to.include?( up.user.email ) }
      emails_to_parent_before = ActionMailer::Base.deliveries.select {| m | m.to.include?( up.parent_user.email ) }
      expect( up ).not_to be_donor
      expect( emails_to_child_before.size ).to eq 0
      up.update( donorbox_donor_id: 1 )
      emails_to_child_after = ActionMailer::Base.deliveries.select {| m | m.to.include?( up.user.email ) }
      emails_to_parent_after = ActionMailer::Base.deliveries.select {| m | m.to.include?( up.parent_user.email ) }
      expect( emails_to_parent_after.size ).to eq emails_to_parent_before.size + 1
      expect( emails_to_child_after.size ).to eq emails_to_child_before.size + 1
    end

    it "delivers emails to child when set on create" do
      up = create( :user_parent, donorbox_donor_id: 1 )
      emails_to_child = ActionMailer::Base.deliveries.select {| m | m.to.include?( up.user.email ) }
      expect( emails_to_child.size ).to eq 1
    end
  end

  describe "virtuous_donor_contact_id" do
    it "gets set on create based on the parent_user" do
      up = UserParent.make!( parent_user: User.make!( virtuous_donor_contact_id: 1 ) )
      expect( up.virtuous_donor_contact_id ).not_to be_blank
      expect( up.virtuous_donor_contact_id ).to eq up.parent_user.virtuous_donor_contact_id
    end

    it "delivers an email to child when set on update" do
      up = create( :user_parent )
      emails_to_child_before = ActionMailer::Base.deliveries.select {| m | m.to.include?( up.user.email ) }
      emails_to_parent_before = ActionMailer::Base.deliveries.select {| m | m.to.include?( up.parent_user.email ) }
      expect( up ).not_to be_donor
      expect( emails_to_child_before.size ).to eq 0
      up.update( virtuous_donor_contact_id: 1 )
      emails_to_child_after = ActionMailer::Base.deliveries.select {| m | m.to.include?( up.user.email ) }
      emails_to_parent_after = ActionMailer::Base.deliveries.select {| m | m.to.include?( up.parent_user.email ) }
      expect( emails_to_parent_after.size ).to eq emails_to_parent_before.size + 1
      expect( emails_to_child_after.size ).to eq emails_to_child_before.size + 1
    end

    it "delivers emails to child when set on create" do
      up = create( :user_parent, virtuous_donor_contact_id: 1 )
      emails_to_child = ActionMailer::Base.deliveries.select {| m | m.to.include?( up.user.email ) }
      expect( emails_to_child.size ).to eq 1
    end
  end
end
