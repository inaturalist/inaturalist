module Privileges
  def self.included( base )
    base.extend ClassMethods
  end
  
  module ClassMethods
    def requires_privilege( privilege, options = {} )
      callback_types = options[:on] || [:create]
      if callback_types.is_a?( Array )
        callback_types.each do |callback_type|
          validate on: callback_type, if: options[:if] do |record|
            unless record.user.privileged_with?( privilege )
              errors.add( :user_id, "requires_privilege_#{privilege}" )
            end
          end
        end
      else
        callback_types.each do |callback_type, attrs|
          validate on: callback_type, if: options[:if] do |record|
            if ![attrs].flatten.blank?
              attrs.each do |attr|
                return unless send( "#{attr}_changed?" )
              end
            end
            unless record.user.privileged_with?( privilege )
              errors.add( :user_id, "requires_privilege_#{privilege}" )
            end
          end
        end
      end
    end
    def earns_privilege( privilege, options = { on: [:create, :destroy]} )
      return if self.included_modules.include?( Privileges::InstanceMethods )
      include HasSubscribers::InstanceMethods

      options[:on].each do |phase|
        send( "after_#{phase}", lambda {
          UserPrivilege.delay.check( user.id, privilege )
        } )
      end
    end
  end

  module InstanceMethods
    # TODO
  end
end
