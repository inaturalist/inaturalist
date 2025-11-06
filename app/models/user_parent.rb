# frozen_string_literal: true

class UserParent < ApplicationRecord
  # This is the child
  belongs_to :user, inverse_of: :user_parent

  # This is the parent's user record
  belongs_to :parent_user, inverse_of: :parentages, class_name: "User"

  validates_format_of :email, with: Devise.email_regexp, message: :must_look_like_an_email_address
  validates :name, presence: true
  validates :child_name, presence: true
  validates :user, presence: true
  validates_associated :user
  validate :email_does_not_belong_to_another_user, on: :create

  accepts_nested_attributes_for :user

  before_validation :strip_strings

  before_create :set_donor_from_parent_user
  after_save :deliver_confirmation_email_if_donor_verified

  def to_s
    "<UserParent #{id} parent_user_id: #{parent_user_id}>"
  end

  def email=( value )
    write_attribute :email, value&.to_s&.downcase
  end

  def strip_strings
    [:name, :child_name, :email].each do | a |
      next if send( a ).blank?

      send( "#{a}=", send( a ).gsub( /[\s\n\t]+/, " " ).strip )
    end
    true
  end

  def set_donor_from_parent_user
    return unless parent_user

    unless parent_user.donorbox_donor_id.blank?
      self.donorbox_donor_id = parent_user.donorbox_donor_id
    end
    return if parent_user.virtuous_donor_contact_id.blank?

    self.virtuous_donor_contact_id = parent_user.virtuous_donor_contact_id
  end

  def deliver_confirmation_email_if_donor_verified
    if donor? && ( (
      # donorbox_donor_id set to something from nil, and virtuous_donor_contact_id is nil
      # or was also set to something from nil at the same time
      saved_change_to_donorbox_donor_id? &&
      previous_changes[:donorbox_donor_id][0].blank? && (
        virtuous_donor_contact_id.blank? || (
          saved_change_to_virtuous_donor_contact_id? &&
          previous_changes[:virtuous_donor_contact_id][0].blank?
        )
      )
    ) || (
      # virtuous_donor_contact_id set to something from nil, and donorbox_donor_id is nil
      # or was also set to something from nil at the same time
      saved_change_to_virtuous_donor_contact_id? &&
      previous_changes[:virtuous_donor_contact_id][0].blank? && (
        donorbox_donor_id.blank? || (
          saved_change_to_donorbox_donor_id? &&
          previous_changes[:donorbox_donor_id][0].blank?
        )
      )
    ) )
      Emailer.user_parent_confirmation( self ).deliver_now
      # In theory the child user did not receive their welcome email when
      # their account was created b/c they were an unverified child account,
      # so now we can welcome them
      user.send_welcome_email
    end
    true
  end

  def email_does_not_belong_to_another_user
    return true if email.blank?

    scope = User.where( email: email )
    scope = scope.where( "id != ?", parent_user.id ) if parent_user
    if scope.exists?
      errors.add( :email, :belongs_to_an_existing_user )
    end
    true
  end

  def donor?
    donorbox_donor_id.to_i.positive? || virtuous_donor_contact_id.to_i.positive?
  end
end
