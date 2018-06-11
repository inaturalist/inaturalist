module HasSubscribers
  def self.included(base)
    base.extend ClassMethods
  end
  
  module ClassMethods
    # Tell a class that it has subscribers
    # :to => {:notofying_association => options}
    #   this is a way to explicitly decalre a notifying association.  This 
    #   will happen automatically from notifies_subscribers_of in most cases, 
    #   but NOT for polymorphic associations
    def has_subscribers(options = {})
      return if self.included_modules.include?(HasSubscribers::InstanceMethods)
      include HasSubscribers::InstanceMethods
      
      has_many :update_subscriptions, class_name: "Subscription", as: :resource, inverse_of: :resource
      has_many :subscribers, through: :update_subscriptions, source: :user
      has_many :update_actions, as: :resource
      
      cattr_accessor :notifying_associations
      self.notifying_associations = options[:to].is_a?(Hash) ? options[:to] : {}

      Subscription.subscribable_classes << to_s
      
      after_destroy do |record|
        UpdateAction.transaction do
          UpdateAction.delete_and_purge(["resource_type = ? AND resource_id = ?", record.class.base_class.name, record.id])
          Subscription.delete_all(["resource_type = ? AND resource_id = ?", record.class.base_class.name, record.id])
        end
        true
      end
    end
    
    # 
    # Tell a model to generate updates for subscribers of an association. For 
    # example, a Comment notifies_subscribers_of :blog_post.
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
    # * <tt>:queue_if</tt> - block to decide whether to queue a record for 
    #   update generation. The :if block determines whether the record
    #   generates an update, but that still happens in a Delayed::Job.
    #   :queue_if determines whether that job gets delayed in the first place. 
    #   Takes the record as its arg.
    # * <tt>:priority</tt> - DJ priority at which to run the notification
    # * <tt>:include_owner</tt> - Create an update for the user associated
    #   with the resource, e.g. if a comment generates an update for an
    #   observation, the owner of the observation should be notified even if
    #   they're not subscribed. This can also be a Proc that takes the
    #   arguments subscribable and notifier.
    # * <tt>:include_notifier</tt> - Create an update for the person
    #   associated with the notifying record.
    #
    def notifies_subscribers_of(subscribable_association, options = {})
      unless self.included_modules.include?(HasSubscribers::InstanceMethods)
        include HasSubscribers::InstanceMethods
      end

      options[:priority] ||= 1
      
      cattr_accessor :notifies_subscribers_of_options
      self.notifies_subscribers_of_options ||= {}
      self.notifies_subscribers_of_options[subscribable_association.to_sym] = options
      
      create_callback(subscribable_association, options)
      
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
        unless record.try(:unsubscribable?) || CONFIG.has_subscribers == :disabled
          UpdateAction.transaction do
            UpdateAction.delete_and_purge(["notifier_type = ? AND notifier_id = ?", record.class.base_class.name, record.id])
          end
        end
      end
    end

    # Generates one-time update for the user associated with a related object
    def notifies_owner_of(subscribable_association, options = {})
      unless self.included_modules.include?(HasSubscribers::InstanceMethods)
        include HasSubscribers::InstanceMethods
      end

      options[:with] ||= :notify_owner_of
      options[:notification] ||= to_s.underscore
      options[:priority] ||= 1

      cattr_accessor :notifies_owner_of_options
      self.notifies_owner_of_options ||= {}
      self.notifies_owner_of_options[subscribable_association.to_sym] = options

      create_callback(subscribable_association, options)
      after_destroy do |record|
        unless record.try(:unsubscribable?) || CONFIG.has_subscribers == :disabled
          UpdateAction.delete_and_purge(["notifier_type = ? AND notifier_id = ?", record.class.name, record.id])
        end
      end
    end

    # Generates one-time update for the user returned by the supplied method
    def notifies_users(method, options = {})
      unless self.included_modules.include?(HasSubscribers::InstanceMethods)
        include HasSubscribers::InstanceMethods
      end

      options[:with] ||= :notify_users
      options[:notification] ||= to_s.underscore
      options[:priority] ||= 1

      cattr_accessor :notifies_users_options
      self.notifies_users_options ||= options

      create_callback(method, options)
      after_destroy do |record|
        unless record.try(:unsubscribable?) || CONFIG.has_subscribers == :disabled
          UpdateAction.delete_and_purge(["notifier_type = ? AND notifier_id = ?", record.class.name, record.id])
        end
      end
    end

    #
    # Subscribe an associated user to an associated object when this record is
    # created. For example, you might auto-subscribe a comment user to the
    # blog post they commented on UNLESS they authored the blog post:
    # 
    #   auto_subscribes :user, :to => :blog_post, :if => {|comment, blog_post| comment.user_id != blog_post.user_id}
    #
    # Options:
    # * <tt>:to</tt> - association to call to retrieve the user
    # * <tt>:if</tt> - block called to determine whether or not to create the
    #   subscription. Takes the record and the subscribable as args.
    #
    def auto_subscribes(subscriber, options = {})
      callback_method = options[:on] == :update ? :after_update : :after_create
      
      send(callback_method) do |record|
        resource = options[:to] ? record.send(options[:to]) : record
        if (options[:if].blank? || options[:if].call(record, resource)) && !record.try(:unsubscribable?) && CONFIG.has_subscribers != :disabled
          Subscription.create(:user => record.send(subscriber), :resource => resource)
        end
      end

      attr_accessor :auto_subscriber

      before_destroy do |record|
        unless record.try(:unsubscribable?) || CONFIG.has_subscribers == :disabled
          record.auto_subscriber = record.send(subscriber)
        end
      end
      
      # this is potentially weird b/c there might be other reasons you're
      # subscribed to something, and this will remove the subscription anyway.
      # alts would be to remove uniqueness constraint so every
      # auto_subscribing object generates a subscription...
      after_destroy do |record|
        unless record.try(:unsubscribable?) || CONFIG.has_subscribers == :disabled
          resource = options[:to] ? record.send(options[:to]) : record
          user = record.auto_subscriber || record.send(subscriber)
          if user && resource
            Subscription.delete_all(:user_id => user.id,
              :resource_type => resource.class.name, :resource_id => resource.id)
          else
            Rails.logger.error "[ERROR #{Time.now}] Couldn't delete auto subscription for #{record}"
          end
        end
      end
    end
    
    def notify_subscribers_with(notifier, subscribable_association)
      return if CONFIG.has_subscribers == :disabled
      options = self.notifies_subscribers_of_options[subscribable_association.to_sym]
      notifier = find_by_id(notifier) unless notifier.is_a?(self)
      has_many_reflections    = reflections.select{|k,v| v.macro == :has_many}.map{|k,v| k.to_s}
      belongs_to_reflections  = reflections.select{|k,v| v.macro == :belongs_to}.map{|k,v| k.to_s}
      has_one_reflections     = reflections.select{|k,v| v.macro == :has_one}.map{|k,v| k.to_s}
      
      notification ||= options[:notification] || "create"
      users_to_notify = { }
      users_with_unviewed_from_notifier = Subscription.users_with_unviewed_updates_from(notifier)
      updater_proc = Proc.new {|subscribable|
        next if subscribable.blank?
        notify_owner = if options[:include_owner].is_a?(Proc)
          options[:include_owner].call(notifier, subscribable)
        elsif options[:include_owner]
          subscribable.respond_to?(:user) && (subscribable == notifier || subscribable.user_id != notifier.user_id)
        end
        if notify_owner
          owner_subscription = subscribable.update_subscriptions.where(user_id: subscribable.user_id).first
          unless owner_subscription
            if options[:if]
              next unless options[:if].call(notifier, subscribable, Subscription.new(resource: subscribable, user: subscribable.user))
            end
            users_to_notify[subscribable] ||= [ ]
            users_to_notify[subscribable] << subscribable.user_id
          end
        end
        
        subscribable.update_subscriptions.with_unsuspended_users.find_each do |subscription|
          next if notifier.respond_to?(:user_id) && subscription.user_id == notifier.user_id && !options[:include_notifier]
          next if subscription.created_at > notifier.updated_at
          next if users_with_unviewed_from_notifier.include?(subscription.user_id)

          if options[:if]
            next unless options[:if].call(notifier, subscribable, subscription)
          end
          users_to_notify[subscribable] ||= [ ]
          users_to_notify[subscribable] << subscription.user_id
        end
      }
      Observation.connection.transaction do
        if has_many_reflections.include?(subscribable_association.to_s)
          notifier.send(subscribable_association).find_each(&updater_proc)
        elsif reflections.detect{|k,v| k.to_s == subscribable_association.to_s}
          updater_proc.call(notifier.send(subscribable_association))
        elsif subscribable_association == :self
          updater_proc.call(notifier)
        else
          subscribable = notifier.send(subscribable_association)
          if subscribable.is_a?(Enumerable)
            subscribable.each(&updater_proc)
          elsif subscribable
            updater_proc.call(subscribable)
          end
        end
      end
      if users_to_notify.length > 0
        users_to_notify.each do |subscribable, user_ids|
          action_attrs = {
            resource: subscribable,
            notifier: notifier,
            notification: notification
          }
          action = UpdateAction.first_with_attributes(action_attrs)
          action.append_subscribers( user_ids )
        end
      end
    end

    def create_callback(subscribable_association, options = {})
      callback_types = []
      options_on = options[:on] ? [options[:on]].flatten.map(&:to_s) : %w(after_create)
      callback_types << :after_update if options_on.detect{|o| o =~ /update/}
      callback_types << :after_create if options_on.detect{|o| o =~ /create/}
      callback_types << :after_save   if options_on.detect{|o| o =~ /save/}
      callback_method = options[:with] || :notify_subscribers_of
      attr_accessor :skip_updates
      callback_types.each do |callback_type|
        send callback_type do |record|
          unless record.skip_updates || record.try(:unsubscribable?)
            if options[:queue_if].blank? || options[:queue_if].call(record)
              if options[:delay] == false
                record.send(callback_method, subscribable_association)
              else
                record.delay(priority: options[:priority]).
                  send(callback_method, subscribable_association)
              end
            end
          end
          true
        end
      end
    end
  end
  
  module InstanceMethods
    def notify_subscribers_of(subscribable_association)
      return if CONFIG.has_subscribers == :disabled
      self.class.send(:notify_subscribers_with, self, subscribable_association)
    end

    def notify_owner_of(association)
      return if CONFIG.has_subscribers == :disabled
      options = self.class.notifies_owner_of_options[association.to_sym]
      action_attrs = {
        resource: send(association),
        notifier: self,
        notification: options[:notification]
      }
      action = UpdateAction.first_with_attributes(action_attrs)
      action.append_subscribers( [send(association).user.id] )
    end

    def notify_users( method )
      return if CONFIG.has_subscribers == :disabled
      options = self.class.notifies_users_options
      resource = observation if respond_to?(:observation)
      resource = parent if is_a?( Comment )
      resource ||= self
      action_attrs = {
        resource: resource,
        notifier: self,
        notification: options[:notification]
      }
      users = send(method)
      except_users = send( options[:except].to_sym ) unless options[:except].blank?
      except_users ||= []
      if users.empty?
        UpdateAction.delete_and_purge(action_attrs)
        return
      end
      users_to_notify = users - except_users
      user_ids = users.map{ |u|
        options[:if].blank? || options[:if].call( u ) ? u.id : nil
      }.compact
      user_ids_to_notify = users_to_notify.map{ |u|
        options[:if].blank? || options[:if].call( u ) ? u.id : nil
      }.compact
      action = UpdateAction.first_with_attributes(action_attrs)
      action.append_subscribers( user_ids_to_notify )
      action.restrict_to_subscribers( user_ids_to_notify )
    end

  end
end
