class UserParent < ActiveRecord::Base
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

  before_create :set_donorbox_donor_id_from_parent_user
  after_save :deliver_confirmation_email_if_donor_verified

  def to_s
    "<UserParent #{id} parent_user_id: #{parent_user_id}>"
  end

  def strip_strings
    [:name, :child_name, :email].each do |a|
      next if send( a ).blank?
      send( "#{a}=", send( a ).gsub(/[\s\n\t]+/, " " ).strip )
    end
    true
  end

  def set_donorbox_donor_id_from_parent_user
    if parent_user && !parent_user.donorbox_donor_id.blank?
      self.donorbox_donor_id = parent_user.donorbox_donor_id
    end
    true
  end

  def deliver_confirmation_email_if_donor_verified
    if donorbox_donor_id_changed? && donorbox_donor_id_was.blank? && donorbox_donor_id.to_i > 0
      Emailer.user_parent_confirmation( self ).deliver_now
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
    donorbox_donor_id.to_i > 0
  end
end
