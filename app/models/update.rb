class Update < ActiveRecord::Base
  belongs_to :subscriber, :class_name => "User"
  belongs_to :resource, :polymorphic => true
  belongs_to :notifier, :polymorphic => true
  
  validates_uniqueness_of :notifier_id, :scope => [:notifier_type, :subscriber_id, :notification]
  
  NOTIFICATIONS = %w(create change activity)
  
  def resource_owner
    resource && resource.respond_to?(:user) ? resource.user : nil
  end
  
  def self.group_and_sort(updates)
    grouped_updates = []
    updates.group_by{|u| [u.resource_type, u.resource_id, u.notification]}.each do |key, updates|
      resource_type, resource_id, notification = key
      updates = updates.sort_by{|u| u.id * -1}
      if notification == "created_observations" && updates.size > 18
        updates.in_groups_of(18) do |bunch|
          grouped_updates << [key, bunch.compact]
        end
      else
        grouped_updates << [key, updates]
      end
    end
    grouped_updates.sort_by {|key, updates| updates.first.id * -1}
  end
  
  def self.email_updates
    start_log_timer
    Update.do_in_batches(:conditions => ["created_at BETWEEN ? AND ?", 1.day.ago, Time.now], :group => :subscriber_id) do |subscriber_id, updates|
      user = User.find_by_id(subscriber_id)
      next unless user
      Emailer.deliver_updates_notification(user, updates)
    end
    end_log_timer
  end
end
