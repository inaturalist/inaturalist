# ActsAsFlaggable
module Gonzo
  module Acts #:nodoc:
    module Flaggable #:nodoc:

      def self.included(base)
        base.extend ClassMethods  
      end

      module ClassMethods
        def acts_as_flaggable
          has_many :flags, :as => :flaggable, :dependent => :destroy
          include Gonzo::Acts::Flaggable::InstanceMethods
          extend Gonzo::Acts::Flaggable::SingletonMethods
        end
      end
      
      # This module contains class methods
      module SingletonMethods
        # Helper method to lookup for flags for a given object.
        # This method is equivalent to obj.flags.
        def find_flags_for(obj)
          flaggable = ActiveRecord::Base.send(:class_name_of_active_record_descendant, self).to_s
         
          Flag.find(:all,
            :conditions => ["flaggable_id = ? and flaggable_type = ?", obj.id, flaggable],
            :order => "created_at DESC"
          )
        end
        
        # Helper class method to lookup flags for
        # the mixin flaggable type written by a given user.  
        # This method is NOT equivalent to Flag.find_flags_for_user
        def find_flags_by_user(user) 
          flaggable = ActiveRecord::Base.send(:class_name_of_active_record_descendant, self).to_s
          
          Flag.find(:all,
            :conditions => ["user_id = ? and flaggable_type = ?", user.id, flaggable],
            :order => "created_at DESC"
          )
        end
      end
      
      # This module contains instance methods
      module InstanceMethods
        
        # Check to see if the passed in user has flagged this object before.
        # Optionally you can test to see if this user has flagged this object
        # with a specific flag
        def user_has_flagged?(user, flag = nil)
          conditions = flag.nil? ? {} : {:flag => flag}
          conditions.merge! ({:user_id => user.id})
          return flags.where(conditions).count > 0
        end
        
        # Count the number of flags tha have this specific
        # flag set
        def count_flags_with_flag(flag)
          flags.where(flag: flag).count
        end
        
        # Add a flag.  You can either pass in an
        # instance of a flag or pass in a hash of attributes to be used to 
        # instantiate a new flag object
        def add_flag(options)
          if options.kind_of?(Hash)
            flag = Flag.new(options)
          elsif options.kind_of?(Flag)
            flag = options
          else
            raise "Invalid options"
          end
          
          flags << flag
          
          # Call flagged to allow model to handle the act of being
          # flagged
          flagged(flag.flag, count_flags_with_flag(flag.flag))
        end
        
        # Meant to be overriden
        protected
        def flagged(flag, flag_count)
        end
      end
      
    end
  end
end
