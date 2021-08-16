class UserMute < ApplicationRecord
  belongs_to :user
  belongs_to :muted_user, class_name: "User"

  validates_presence_of :user
  validates_presence_of :muted_user
  validate :cant_mute_yourself
  validates_uniqueness_of :muted_user_id, scope: :user_id, message: "already muted"

  def cant_mute_yourself
    if muted_user_id == user_id
      errors.add( :muted_user_id, "can't be you" )
    end
    true
  end

end
