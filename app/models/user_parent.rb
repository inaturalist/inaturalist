class UserParent < ActiveRecord::Base
  belongs_to :user, inverse_of: :user_parent
  belongs_to :parent_user, inverse_of: :parentages, class_name: "User"
  validates_format_of :email, with: Devise.email_regexp, message: :must_look_like_an_email_address
  validates :name, presence: true
  validates :child_name, presence: true
  validates :user, presence: true
  validates_associated :user

  accepts_nested_attributes_for :user
end
