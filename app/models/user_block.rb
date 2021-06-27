class UserBlock < ActiveRecord::Base
  # After a single user has been blocked this many times we alert staff about it
  PROBLEMATIC_BLOCK_THRESHOLD = 3
  # Number of blocks allowed per user
  BLOCK_QUOTA = 3
  belongs_to :user
  belongs_to :blocked_user, class_name: "User"
  # User who OK'd an override to one of the validations
  belongs_to :override_user, class_name: "User"

  validates_presence_of :user
  validates_presence_of :blocked_user
  validate :only_three_per_user, on: :create
  validate :cant_block_yourself
  validate :cant_block_staff
  validate :uniqueness_of_blocked_user, on: :create

  after_create :destroy_friendships, :notify_staff_about_potential_problem_user

  def to_s
    "<UserBlock #{id} user_id: #{user_id}, blocked_user_id: #{blocked_user_id}>"
  end

  def only_three_per_user
    if user.user_blocks.count >= BLOCK_QUOTA && ( override_user.blank? || !override_user.is_admin? )
      errors.add( :base, I18n.t( "you_can_only_block_three_users" ) )
    end
    true
  end

  def cant_block_yourself
    if blocked_user_id == user_id
      errors.add( :blocked_user_id, "can't be you" )
    end
    true
  end

  def cant_block_staff
    if blocked_user && blocked_user.is_admin?
      errors.add( :base, :user_cannot_be_staff )
    end
    true
  end

  def uniqueness_of_blocked_user
    if blocked_user && user.user_blocks.where( blocked_user_id: blocked_user ).exists?
      errors.add( :base, :user_already_blocked )
    end
    true
  end


  def destroy_friendships
    Friendship.where( user_id: user_id, friend_id: blocked_user_id ).destroy_all
    Friendship.where( user_id: blocked_user_id, friend_id: user_id ).destroy_all
    true
  end

  def notify_staff_about_potential_problem_user
    if UserBlock.where( blocked_user_id: blocked_user_id ).count == PROBLEMATIC_BLOCK_THRESHOLD
      Emailer.notify_staff_about_blocked_user( blocked_user ).deliver
    end
    true
  end
end
