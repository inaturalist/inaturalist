class ActivityStream < ActiveRecord::Base
  belongs_to :user
  belongs_to :subscriber, :class_name => 'User', :foreign_key => 'subscriber_id'
  belongs_to :activity_object, :polymorphic => true
  
  def to_s
    "<ActivityStream id: #{id}, user_id: #{user_id}, subscriber_id: #{subscriber_id}, " +
      "activity_object_type: #{activity_object_type}, activity_object_id: #{activity_object_id}"
  end
  
  # Destroys activity streams that have an activity_object that no longer 
  # exists
  def self.destroy_nils_for_activity_object_type(klass)
    as = ActivityStream.all(
      :joins => "LEFT OUTER JOIN #{klass.table_name} ON #{klass.table_name}.id = activity_streams.activity_object_id", 
      :conditions => "#{klass.table_name}.id is null AND activity_object_type = '#{klass.to_s}'")
    as.each(&:destroy)
  end
end
