# For models that record the user that made the last update, we need to ensure
# this gets nilified if the record was not actually updated by a user
module HasUpdater
  def self.included(base)
    base.extend ClassMethods
  end
  
  module ClassMethods
    def has_updater
      belongs_to :updater, class_name: "User"
      attr_accessor :updater_assigned
      include HasUpdater::InstanceMethods
      before_save :remove_updater_if_not_explicitly_assigned
    end
  end

  module InstanceMethods
    def updater=( user )
      self.updater_assigned = true
      super( user )
    end

    def updater_id=( user_id )
      self.updater_assigned = true
      super( user_id )
    end

    def remove_updater_if_not_explicitly_assigned
      self.updater = nil unless self.updater_assigned
      true
    end
  end
end

ActiveRecord::Base.send(:include, HasUpdater)
