# -*- coding: utf-8 -*-
require File.dirname(__FILE__) + '/../spec_helper'

describe UserParent do
  it { is_expected.to belong_to(:user).inverse_of :user_parent }
  it { is_expected.to belong_to(:parent_user).inverse_of(:parentages).class_name "User" }

  it { is_expected.to validate_presence_of :name }
  it { is_expected.to validate_presence_of :child_name }
  it { is_expected.to validate_presence_of :user }

  describe UserParent, "creation" do
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

  describe UserParent, "update" do
    it "should allow the donorbox_donor_id to be set even if a non-parent user exists with the same email address" do
      up = UserParent.make!
      u = User.make!( email: up.email )
      up.update( donorbox_donor_id: 1 )
      expect( up ).to be_valid
    end
  end

  describe UserParent, "donorbox_donor_id" do
    it "should get set on create based on the parent_user" do
      up = UserParent.make!( parent_user: User.make!( donorbox_donor_id: 1 ) )
      expect( up.donorbox_donor_id ).not_to be_blank
      expect( up.donorbox_donor_id ).to eq up.parent_user.donorbox_donor_id
    end
    it "should deliver an email when set on update" do
      up = UserParent.make!
      deliveries = ActionMailer::Base.deliveries.size
      up.update( donorbox_donor_id: 1 )
      expect( ActionMailer::Base.deliveries.size ).to eq deliveries + 1
    end
    it "should deliver an email when set on create" do
      deliveries = ActionMailer::Base.deliveries.size
      up = UserParent.make!( donorbox_donor_id: 1 )
      expect( ActionMailer::Base.deliveries.size ).to eq deliveries + 1
    end
  end
end
