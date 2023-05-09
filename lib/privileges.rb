# frozen_string_literal: true

module Privileges
  def self.included( base )
    base.extend ClassMethods
  end

  module ClassMethods
    def requires_privilege( privilege, options = {} )
      callback_types = options[:on] || [:create]
      if callback_types.is_a?( Hash )
        callback_types.each do | callback_type, attrs |
          validate on: callback_type, if: options[:if] do | record |
            unless [attrs].flatten.blank?
              attrs.each do | attr |
                return false unless send( "#{attr}_changed?" )
              end
            end
            unless record.user.privileged_with?( privilege )
              errors.add( :user_id, "requires_privilege_#{privilege}".to_sym )
            end
          end
        end
      else
        callback_types = [callback_types].flatten
        callback_types.each do | callback_type |
          validate on: callback_type, if: options[:if] do | record |
            unless record.user&.privileged_with?( privilege )
              errors.add( :user_id, "requires_privilege_#{privilege}".to_sym )
            end
          end
        end
      end
    end

    def earns_privilege( privilege, options = { on: [:create, :destroy] } )
      unless included_modules.include?( Privileges::InstanceMethods )
        include Privileges::InstanceMethods
      end

      options[:on].each do | phase |
        send( "after_#{phase}", lambda {
          UserPrivilege.delay(
            unique_hash: "UserPrivilege.check(#{user.id},#{privilege})",
            run_at: 1.hours.from_now # this will probably have to change if / we start using privileges
          ).check( user.id, privilege )
          true
        } )
      end
    end
  end

  module InstanceMethods
    # TODO
  end

  module Controller
    def self.included( base )
      base.extend ClassMethods
    end

    module ClassMethods
      def requires_privilege( privilege, options = {} )
        before_action( options ) do
          if current_user &&
              !current_user.privileged_with?( privilege ) &&
              !current_user.is_admin? &&
              !current_user.is_curator?

            msg = t( "activerecord.errors.messages.requires_privilege_#{privilege}" )
            respond_to do | format |
              format.html do
                flash[:notice] = msg
                redirect_back_or_default( root_url )
              end
              format.json do
                return render json: { error: msg }, status: :forbidden
              end
            end
          end
        end
      end
    end
  end
end
