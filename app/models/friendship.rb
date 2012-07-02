class Friendship < ActiveRecord::Base
  belongs_to :user
  belongs_to :friend, :class_name => 'User', :foreign_key => 'friend_id'
  
  validates_uniqueness_of :friend_id, :scope => :user_id
  validate :no_self_love
  
  auto_subscribes :user, :to => :friend
  
  def no_self_love
    errors.add_to_base("Cannot be a friend of yourself. Hopefully you already are.") unless friend_id != user_id
  end

end
