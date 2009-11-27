module Shared
  module ActivityStreamable
    def self.included(ar)
      ar.has_many :activity_streams
      ar.after_create :create_activity_update
    end
    
    def create_activity_update
      self.user.followers.each do |follower|
        ActivityStream.create({
          :user_id => self.user_id,
          :subscriber_id => follower.id,
          :activity_object => self
        })
      end
    end
  end
end