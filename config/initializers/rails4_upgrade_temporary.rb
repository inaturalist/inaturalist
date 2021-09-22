# this was needed because apparently HABTM relationships are not rolling back
# for example this will raise an error
# User.transaction do
#   User.last.roles << Role.last
#   raise ActiveRecord::Rollback
# end
#
# Apparently there is a model User::HABTM_Roles now, and it has no primary key
# which is causing problems here
# module ActiveRecord
#   # See ActiveRecord::Transactions::ClassMethods for documentation.
#   module Transactions

#     protected

#     # Restore the new record state and id of a record that was previously saved by a call to save_record_state.
#     def restore_transaction_record_state(force = false) #:nodoc:
#       unless @_start_transaction_state.empty?
#         transaction_level = (@_start_transaction_state[:level] || 0) - 1
#         if transaction_level < 1 || force
#           restore_state = @_start_transaction_state
#           thaw unless restore_state[:frozen?]
#           @new_record = restore_state[:new_record]
#           @destroyed  = restore_state[:destroyed]
#           # pleary: all I added was this conditional
#           if self.class.primary_key
#             write_attribute(self.class.primary_key, restore_state[:id])
#           end
#         end
#       end
#     end
#   end
# end



# # preferences was failing because this method no longer existed on ActiveRecord::Base
# # for example try logging in and changing the number of items per page
# module ActiveRecord
#   class Base
#     def convert_number_column_value(value)
#       if value == false
#         0
#       elsif value == true
#         1
#       elsif value.is_a?(String) && value.blank?
#         nil
#       else
#         value
#       end
#     end
#   end
# end
