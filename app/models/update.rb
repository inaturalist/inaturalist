class Update < ActiveRecord::Base
  belongs_to :subscriber, :class_name => "User"
  belongs_to :resource, :polymorphic => true
  belongs_to :notifier, :polymorphic => true
  
  validates_uniqueness_of :notifier_id, :scope => [:notifier_type, :subscriber_id, :notification]
  
  NOTIFICATIONS = %w(create change activity)
  
  def resource_owner
    resource && resource.respond_to?(:user) ? resource.user : nil
  end
end
