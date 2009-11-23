class ActivityStream < ActiveRecord::Base
  belongs_to :user
  belongs_to :subscriber, :class_name => 'User', :foreign_key => 'subscriber_id'
  belongs_to :activity_object, :polymorphic => true
end
