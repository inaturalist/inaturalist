class ActivityStream < ActiveRecord::Base
  belongs_to :user
  belongs_to :subscriber, :class_name => 'User', :foreign_key => 'subscriber_id'
  belongs_to :activity_object, :polymorphic => true
  
  def to_s
    "<ActivityStream id: #{id}, user_id: #{user_id}, subscriber_id: #{subscriber_id}, " +
      "activity_object_type: #{activity_object_type}, activity_object_id: #{activity_object_id}"
  end
  
  def activity_object_name
    activity_object.class.to_s.underscore.humanize.downcase
  end
  
  # Destroys activity streams that have an activity_object that no longer 
  # exists
  def self.destroy_nils_for_activity_object_type(klass)
    as = ActivityStream.all(
      :joins => "LEFT OUTER JOIN #{klass.table_name} ON #{klass.table_name}.id = activity_streams.activity_object_id", 
      :conditions => "#{klass.table_name}.id is null AND activity_object_type = '#{klass.to_s}'")
    as.each(&:destroy)
  end

  # Takes a collection of activity streams and tries to eager load associates.
  # Since an activity stream can have both a polymorphic one-to-one relation
  # with its activity_object OR pseudo-one-to-many relationship with all the
  # objects specified in batch_ids, this gets a little less than trivial.
  def self.eager_load_associates(activity_streams, options = {})
    activity_object_ids = {}
    associates = {}
    activity_objects_by_update_id = {}
    batch_limit = options.delete(:batch_limit)
    includes = options.delete(:includes) || {}
    
    # Load all the associate ids into a hash keyed by associate type
    activity_streams.each do |update|
      activity_object_ids[update.activity_object_type] ||= []
      activity_object_ids[update.activity_object_type] += if update.batch_ids.blank?
        [update.activity_object_id]
      else
        if batch_limit
          update.batch_ids.split(',')[0...batch_limit]
        else
          update.batch_ids.split(',')
        end
      end
      activity_object_ids[update.activity_object_type] = 
        activity_object_ids[update.activity_object_type].flatten.uniq
    end
    
    # Load all associates into a hash keyed by type
    activity_object_ids.each do |as_type, ids|
      associates[as_type.underscore.pluralize.to_sym] = Object.const_get(as_type).all(
        :conditions => ["id IN (?)", ids.map(&:to_i)], 
        :include => includes[as_type]
      )
    end
    
    # Hash associates by activity stream id
    activity_streams.each do |update|
      activity_objects = associates[update.activity_object_type.underscore.pluralize.to_sym]
      activity_objects_by_update_id[update.id] = activity_objects.select do |ao|
        ao.id == update.activity_object_id || 
          (!update.batch_ids.blank? && 
            update.batch_ids.split(',').include?(ao.id.to_s))
      end
    end
    
    [activity_objects_by_update_id, associates]
  end
end
