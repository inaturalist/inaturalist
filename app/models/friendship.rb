class Friendship < ActiveRecord::Base
  belongs_to :user
  belongs_to :friend, class_name: "User", foreign_key: "friend_id"
  
  validates_uniqueness_of :friend_id, scope: :user_id
  validates_presence_of :friend_id
  validates_presence_of :user_id
  validate :no_self_love
  
  auto_subscribes :user, to: :friend, if: Proc.new{|friendship, friend| friendship.following?}
  blockable_by lambda {|friendship| friendship.user_id }
  blockable_by lambda {|friendship| friendship.friend_id }

  after_update :remove_subscription_to_friend, if: Proc.new{|friendship|
    friendship.following_changed? && !friendship.following?
  }
  after_update :create_subscription_after_update, if: Proc.new{|friendship|
    friendship.following_changed? && friendship.following?
  }
  after_destroy :remove_subscription_to_friend
  
  def no_self_love
    errors[:base] << "Cannot be a friend of yourself. Hopefully you already are." unless friend_id != user_id
  end

  def remove_subscription_to_friend
    Subscription.where( user_id: user.id, resource: friend ).destroy_all
    true
  end

  def create_subscription_after_update
    Subscription.create( user: user, resource: friend )
    true
  end

  def self.merge_future_duplicates( reject, keeper )
    reject.friendships.where( friend_id: keeper.friendships.pluck(:friend_id) ).delete_all
    reject.friendships.update_all( user_id: keeper.id )
  end

end
