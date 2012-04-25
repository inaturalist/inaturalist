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
    Rails.logger.info "[INFO #{Time.now}] start daily updates emailer"
    start_time = 1.day.ago.utc
    end_time = Time.now.utc
    email_count = 0
    user_ids = Update.all(
        :select => "DISTINCT subscriber_id",
        :conditions => ["created_at BETWEEN ? AND ?", start_time, end_time]).map{|u| u.subscriber_id}.compact
    user_ids.each do |subscriber_id|
      user = User.find_by_id(subscriber_id)
      next unless user
      next if user.email.blank?
      next unless user.active? # email verified
      next unless user.admin? # testing
      updates = Update.all(:conditions => ["subscriber_id = ? AND created_at BETWEEN ? AND ?", subscriber_id, start_time, end_time])
      updates.delete_if do |u| 
        !user.prefers_comment_email_notification? && u.notifier_type == "Comment" ||
        !user.prefers_identification_email_notification? && u.notifier_type == "Identification"
      end
      next if updates.blank?
      Emailer.deliver_updates_notification(user, updates)
      email_count += 1
    end
    Rails.logger.info "[INFO #{Time.now}] end daily updates emailer, sent #{email_count} in #{Time.now - end_time} s"
  end
  
  def self.eager_load_associates(updates, options = {})
    includes = options[:includes] || {
      :observation => [:user, {:taxon => :taxon_names}, :iconic_taxon, :photos],
      :identification => [:user, {:taxon => [:taxon_names, :photos]}, {:observation => :user}],
      :comment => [:user, :parent],
      :listed_taxon => [{:list => :user}, {:taxon => [:photos, :taxon_names]}]
    }
    update_cache = {}
    [Comment, Identification, Observation, ListedTaxon, Post].each do |klass|
      ids = updates.map do |u|
        if u.notifier_type == klass.to_s
          u.notifier_id
        elsif u.resource_type == klass.to_s
          u.resource_id
        else
          nil
        end
      end.compact
      update_cache[klass.to_s.underscore.pluralize.to_sym] = klass.all(
        :conditions => ["id IN (?)", ids], 
        :include => includes[klass.to_s.underscore.to_sym]
      ).index_by{|o| o.id}
    end
    update_cache
  end
end
