module Shared
  module ActivityStreamable
    attr_accessor :skip_update
    
    def self.included(ar)
      ar.has_many :activity_streams
      ar.after_create :create_activity_update
    end
    
    def create_activity_update
      return if @skip_update
      return unless self.respond_to?(:user) && self.user
      self.user.followers.each do |follower|
        ActivityStream.create(
          :user_id => self.user_id,
          :subscriber_id => follower.id,
          :activity_object => self
        )
      end
    end
  end
end