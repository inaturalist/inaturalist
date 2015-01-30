# this was needed to allow geom types to be entered in tests
# Very similar to what the spatial_adapter gem was doing for us
module ActiveRecord
  module Type
    class Value

      # Cast a value from the ruby type to a type that the database knows how
      # to understand. The returned value from this method should be a
      # +String+, +Numeric+, +Date+, +Time+, +Symbol+, +true+, +false+, or
      # +nil+
      def type_cast_for_database(value)
        # pleary: this conditional is the new bit
        if value.kind_of? GeoRuby::SimpleFeatures::Geometry
          return value.as_hex_ewkb
        end
        value
      end
    end
  end
end



# this was needed because apparently HABTM relationships are not rolling back
# for example this will raise an error
# User.transation do
#   User.last.roles << Role.last
#   raise ActiveRecord::Rollback
# end
#
# Apparently there is a model User::HABTM_Roles now, and it has no primary key
# which is causing problems here
module ActiveRecord
  # See ActiveRecord::Transactions::ClassMethods for documentation.
  module Transactions

    protected

    # Restore the new record state and id of a record that was previously saved by a call to save_record_state.
    def restore_transaction_record_state(force = false) #:nodoc:
      unless @_start_transaction_state.empty?
        transaction_level = (@_start_transaction_state[:level] || 0) - 1
        if transaction_level < 1 || force
          restore_state = @_start_transaction_state
          thaw unless restore_state[:frozen?]
          @new_record = restore_state[:new_record]
          @destroyed  = restore_state[:destroyed]
          # pleary: all I added was this conditional
          if self.class.primary_key
            write_attribute(self.class.primary_key, restore_state[:id])
          end
        end
      end
    end
  end
end