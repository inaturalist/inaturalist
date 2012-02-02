module ActiveRecord
  module Calculations
    # module ClassMethods
      GEO_OPERATIONS = %w(extent)
      FLOAT_REGEX = /[-+]?[0-9]*\.?[0-9]+/
      
      private
      
      # Alias and override for geo calculation operations
      alias :_type_cast_calculated_value :type_cast_calculated_value
      def type_cast_calculated_value(*args)
        value, column, operation = args
        return _type_cast_calculated_value(*args) unless GEO_OPERATIONS.include?(operation.to_s)
        case operation.to_s
        when 'extent'
          return nil if value.blank?
          matches = value.match(
            /(#{FLOAT_REGEX}) (#{FLOAT_REGEX}),(#{FLOAT_REGEX}) (#{FLOAT_REGEX})/
          )
          if matches.blank?
            nil
          else
            GeoRuby::SimpleFeatures::Envelope.from_coordinates(
              matches[1..-1].map(&:to_f).in_groups_of(2)
            )
          end
        end
      end
    # end
  end
end
