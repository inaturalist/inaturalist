# frozen_string_literal: true

class Friendship < ApplicationRecord
  belongs_to :user
  belongs_to_with_uuid :friend, class_name: "User", foreign_key: "friend_id"

  validates_uniqueness_of :friend_id, scope: :user_id
  validates_presence_of :friend
  validates_presence_of :friend_id
  validates_presence_of :user
  validates_presence_of :user_id
  validate :no_self_love

  auto_subscribes :user, to: :friend, if: proc {| friendship, _friend | friendship.following? }

  requires_privilege :interaction

  blockable_by ->( friendship ) { friendship.user_id }
  blockable_by ->( friendship ) { friendship.friend_id }

  after_update :remove_subscription_to_friend, if: proc {| friendship |
    friendship.saved_change_to_following? && !friendship.following?
  }
  after_update :create_subscription_after_update, if: proc {| friendship |
    friendship.saved_change_to_following? && friendship.following?
  }
  after_destroy :remove_subscription_to_friend

  def no_self_love
    return if friend_id != user_id

    errors.add( :base, "Cannot be a friend of yourself. Hopefully you already are." )
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
    reject.friendships.where( friend_id: keeper.friendships.pluck( :friend_id ) ).delete_all
    reject.friendships.update_all( user_id: keeper.id )
  end
end
