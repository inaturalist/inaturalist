module HasSubscribers
  def self.included(base)
    base.extend ClassMethods
  end
  
  module ClassMethods
    def has_subscribers(options = {})
      return if self.included_modules.include?(HasSubscribers::InstanceMethods)
      include HasSubscribers::InstanceMethods
      
      has_many :subscriptions, :as => :resource
      has_many :subscribers, :through => :subscriptions, :source => :user
      
      after_destroy do |record|
        Update.delete_all(["resource_type = ? AND resource_id = ?", to_s, record.id])
      end
    end
    
    def notifies_subscribers_of(subscribable_association, options = {})
      unless self.included_modules.include?(HasSubscribers::InstanceMethods)
        include HasSubscribers::InstanceMethods
      end
      
      callback_type = case options[:on]
      when :update then :after_update
      else :after_create
      end
      callback_method = options[:on] || :notify_subscribers_of
      send callback_type do |record|
        record.send(callback_method, subscribable_association, options)
      end
      
      after_destroy do |record|
        Update.delete_all(["notifier_type = ? AND notifier_id = ?", to_s, record.id])
      end
    end
    
    # auto_subscribes :user, :to => :friend
    def auto_subscribes(subscriber, options = {})
      after_create do |record|
        resource = options[:to] ? record.send(options[:to]) : record
        Subscription.create(:user => record.send(subscriber), :resource => resource)
      end
      
      # this is potentially weird b/c there might be other reasons you're subscribed to something, and this will remove the subscription anyway. alts would be to remove uniqueness constraint so every auto_subscribing object generates a subscription...
      after_destroy do |record|
        resource = options[:to] ? record.send(options[:to]) : record
        Subscription.delete_all(:user_id => record.send(subscriber).id, 
          :resource_type => resource.class.to_s, :resource_id => resource.id)
      end
    end
    
    def notify_subscribers_of(notifier, subscribable_association, options = {})
      notifier = find_by_id(notifier) unless notifier.is_a?(self)
      has_many_reflections    = reflections.select{|k,v| v.macro == :has_many}.map{|k,v| k.to_s}
      belongs_to_reflections  = reflections.select{|k,v| v.macro == :has_many}.map{|k,v| k.to_s}
      has_one_reflections     = reflections.select{|k,v| v.macro == :has_one}.map{|k,v| k.to_s}
      
      notification ||= options[:notification] || "create"
      
      updater_proc = Proc.new {|subscribable|
        if options[:include_owner] && subscribable.respond_to?(:user) && subscribable.user_id != notifier.user_id
          owner_subscription = subscribable.subscriptions.first(:conditions => {:user_id => subscribable.user_id})
          unless owner_subscription
            Update.create(:subscriber => subscribable.user, :resource => subscribable, :notifier => notifier, 
              :notification => notification)
          end
        end
        
        subscribable.subscriptions.find_each do |subscription|
          Update.create(:subscriber => subscription.user, :resource => subscribable, :notifier => notifier, 
            :notification => notification)
        end
      }
      
      if has_many_reflections.include?(subscribable_association.to_s)
        Rails.logger.debug "[DEBUG] creating updates for has_many relat"
        notifier.send(subscribable_association).find_each(updater_proc)
      elsif reflections.detect{|k,v| k.to_s == subscribable_association.to_s}
        Rails.logger.debug "[DEBUG] creating updates for another relat"
        updater_proc.call(notifier.send(subscribable_association))
      else
        subscribable = notifier.send(subscribable_association)
        if subscribable.is_a?(Enumerable)
          Rails.logger.debug "[DEBUG] creating updates for enumerable"
          subscribable.each(updater_proc)
        else
          Rails.logger.debug "[DEBUG] creating updates for single attr/meth"
          updater_proc.call(subscribable)
        end
      end
    end
  end
  
  module InstanceMethods
    def notify_subscribers_of(subscribable_association, options = {})
      self.class.send(:notify_subscribers_of, self, subscribable_association, options)
    end
  end
end
