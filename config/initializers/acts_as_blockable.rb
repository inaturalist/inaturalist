module ActsAsBlockable

  extend ActiveSupport::Concern

  class_methods do
    def blockable_by( user_finder )
      validate do
        blocking_user = user_finder.call( self )
        if !user || !blocking_user
          true
        elsif blocking_user.user_blocks( blocked_user_id: user.id ).exists?
          errors.add( :base, I18n.t( :you_dont_have_permission_to_do_that ) )
        end
        true
      end
    end
  end
end

ActiveRecord::Base.send(:include, ActsAsBlockable)
