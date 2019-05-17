class UserParent < ActiveRecord::Base
  belongs_to :user, inverse_of: :user_parent
  belongs_to :parent_user, inverse_of: :parentages, class_name: "User"
  validates_format_of :email, with: Devise.email_regexp, message: :must_look_like_an_email_address
  validates :name, presence: true
  validates :child_name, presence: true
  validates :user, presence: true
  validates_associated :user

  accepts_nested_attributes_for :user

  after_update :deliver_confirmation_email_if_donor_verified

  def deliver_confirmation_email_if_donor_verified
    if donorbox_donor_id_changed? && donorbox_donor_id_was.blank? && donorbox_donor_id.to_i > 0
      Emailer.user_parent_confirmation( self ).deliver_now
    end
    true
  end
end
