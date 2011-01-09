class Friendship < ActiveRecord::Base
  belongs_to :user
  belongs_to :friend, :class_name => 'User', :foreign_key => 'friend_id'
  
  validates_uniqueness_of :friend_id, :scope => :user_id
  validate :no_self_love
  
  after_create :create_activity_stream_for_last_observation
  after_destroy :clear_activity_streams
  
  def no_self_love
    errors.add_to_base("Cannot be a friend of yourself. Hopefully you already are.") unless friend_id != user_id
  end
  
  def create_activity_stream_for_last_observation
    return true unless observation = friend.observations.last
    ActivityStream.create(
      :user_id => observation.user_id,
      :subscriber_id => user_id,
      :activity_object => observation
    )
    true
  end
  
  def clear_activity_streams
    ActivityStream.delete_all(["user_id = ? AND subscriber_id = ?", friend, user])
    true
  end
end
