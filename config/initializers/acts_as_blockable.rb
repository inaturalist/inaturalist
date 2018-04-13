module ActsAsBlockable

  extend ActiveSupport::Concern

  class_methods do
    def blockable_by( user_id_finder, options = {} )
      validate do
        blocking_user_id = user_id_finder.call( self )
        blocking_user_id = blocking_user_id.id if blocking_user_id.is_a?( User )
        blockable_user_id = if options[:blockable_user_id]
          options[:blockable_user_id].call( self )
        else
          try(:user_id) || try(:user).try(:id)
        end
        if !blockable_user_id || !blocking_user_id
          true
        elsif UserBlock.where( user_id: [blocking_user_id, blockable_user_id], blocked_user_id: [blocking_user_id, blockable_user_id] ).exists?
          errors.add( :base, I18n.t( :you_dont_have_permission_to_do_that ) )
        end
        true
      end
    end
  end
end

ActiveRecord::Base.send(:include, ActsAsBlockable)
