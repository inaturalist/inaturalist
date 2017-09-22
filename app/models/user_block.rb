class UserBlock < ActiveRecord::Base
  belongs_to :user
  belongs_to :blocked_user, class_name: "User"

  validate :only_three_per_user, on: :create
  validate :cant_block_yourself
  validates_uniqueness_of :blocked_user_id, scope: :user_id, message: "already blocked"

  after_create :destroy_friendships

  def only_three_per_user
    if user.user_blocks.count >= 3
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

  def destroy_friendships
    Friendship.where( user_id: user_id, friend_id: blocked_user_id ).destroy_all
    Friendship.where( user_id: blocked_user_id, friend_id: user_id ).destroy_all
    true
  end
end
