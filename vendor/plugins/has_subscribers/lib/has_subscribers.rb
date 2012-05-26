module HasSubscribers
  def self.included(base)
    base.extend ClassMethods
  end
  
  module ClassMethods
    # designate that a class has subscribers
    # :to => {:notofying_association => options}
    #   this is a way to explicitly decalre a notifying association.  This 
    #   will happen automatically from notifies_subscribers_of in most cases, 
    #   but NOT for polymorphic associations
    def has_subscribers(options = {})
      return if self.included_modules.include?(HasSubscribers::InstanceMethods)
      include HasSubscribers::InstanceMethods
      
      has_many :update_subscriptions, :class_name => "Subscription", :as => :resource
      has_many :subscribers, :through => :update_subscriptions, :source => :user
      
      cattr_accessor :notifying_associations
      self.notifying_associations = options[:to].is_a?(Hash) ? options[:to] : {}
      
      after_destroy do |record|
        Update.delete_all(["resource_type = ? AND resource_id = ?", to_s, record.id])
      end
    end
    
    # 
    # Model generates updates for subscribers of an association. For example,
    # a Common notifies_subscribers_of :blog_post.
    # 
    # Configuration options:
    # * <tt>:on</tt> - event that triggers notification. Values: update or 
    #   create.
    # * <tt>:with</tt> - name of an instance method that notifies subscribers.
    #   Use this if you want to customize the way updates get generated.
    # * <tt>:if</tt> - block to decide whether to send generate an update. 
    #   Takes the following arguments: notifier, associate, subscription.  So
    #   if a comment was going to generate updates for subscribers to its
    #   parent blog post, the arguments would be comment, blog_post,
    #   subscription, and this block would get called for every subscription.
    #
    def notifies_subscribers_of(subscribable_association, options = {})
      unless self.included_modules.include?(HasSubscribers::InstanceMethods)
        include HasSubscribers::InstanceMethods
      end
      
      cattr_accessor :notifies_subscribers_of_options
      @@notifies_subscribers_of_options ||= {}
      @@notifies_subscribers_of_options[subscribable_association.to_sym] = options.merge(:dj_priority => 1)
      
      callback_type = case options[:on]
      when :update then :after_update
      else :after_create
      end
      callback_method = options[:with] || :notify_subscribers_of
      send callback_type do |record|
        record.send_later(callback_method, subscribable_association)
      end
      
      if Object.const_defined?(subscribable_association.to_s.classify) && 
          (klass = Object.const_get(subscribable_association.to_s.classify)) && 
          (klass.reflections.detect{|k,v| k == to_s.underscore.pluralize.to_sym} || klass.respond_to?(to_s.underscore.pluralize.to_sym))
        klass.notifying_associations[to_s.underscore.pluralize.to_sym] ||= options
      end
      
      if self.respond_to?(:associations_to_notify)
        self.associations_to_notify[subscribable_association.to_sym] = options
      else
        cattr_accessor :associations_to_notify
        self.associations_to_notify = {
          subscribable_association.to_sym => options
        }
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
    
    def notify_subscribers_with(notifier, subscribable_association)
      options = @@notifies_subscribers_of_options[subscribable_association.to_sym]
      notifier = find_by_id(notifier) unless notifier.is_a?(self)
      has_many_reflections    = reflections.select{|k,v| v.macro == :has_many}.map{|k,v| k.to_s}
      belongs_to_reflections  = reflections.select{|k,v| v.macro == :has_many}.map{|k,v| k.to_s}
      has_one_reflections     = reflections.select{|k,v| v.macro == :has_one}.map{|k,v| k.to_s}
      
      notification ||= options[:notification] || "create"
      
      updater_proc = Proc.new {|subscribable|
        if options[:include_owner] && subscribable.respond_to?(:user) && subscribable.user_id != notifier.user_id
          owner_subscription = subscribable.update_subscriptions.first(:conditions => {:user_id => subscribable.user_id})
          unless owner_subscription
            Update.create(:subscriber => subscribable.user, :resource => subscribable, :notifier => notifier, 
              :notification => notification)
          end
        end
        
        subscribable.update_subscriptions.find_each do |subscription|
          next if notifier.respond_to?(:user_id) && subscription.user_id == notifier.user_id
          next if subscription.created_at > notifier.created_at
          next if subscription.has_unviewed_updates_from(notifier)
          
          if options[:if]
            next unless options[:if].call(notifier, subscribable, subscription)
          end
          
          Update.create(:subscriber => subscription.user, :resource => subscribable, :notifier => notifier, 
            :notification => notification)
        end
      }
      
      if has_many_reflections.include?(subscribable_association.to_s)
        notifier.send(subscribable_association).find_each(&updater_proc)
      elsif reflections.detect{|k,v| k.to_s == subscribable_association.to_s}
        updater_proc.call(notifier.send(subscribable_association))
      else
        subscribable = notifier.send(subscribable_association)
        if subscribable.is_a?(Enumerable)
          subscribable.each(&updater_proc)
        else
          updater_proc.call(subscribable)
        end
      end
    end
  end
  
  module InstanceMethods
    def notify_subscribers_of(subscribable_association)
      self.class.send(:notify_subscribers_with, self, subscribable_association)
    end
  end
end
