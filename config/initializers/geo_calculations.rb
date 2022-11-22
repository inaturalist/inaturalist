# frozen_string_literal: true

module ActiveRecord
  module Calculations
    GEO_OPERATIONS = %w(extent).freeze
    FLOAT_REGEX = /[-+]?[0-9]*\.?[0-9]+/.freeze

    private

    # Alias and override for geo calculation operations
    alias _type_cast_calculated_value type_cast_calculated_value
    def type_cast_calculated_value( *args, &block )
      value, _column, operation = args
      return _type_cast_calculated_value( *args, &block ) unless GEO_OPERATIONS.include?( operation.to_s )

      case operation.to_s
      when "extent"
        return nil if value.blank?

        matches = value.match(
          /(#{FLOAT_REGEX}) (#{FLOAT_REGEX}),(#{FLOAT_REGEX}) (#{FLOAT_REGEX})/
        )
        if matches.blank?
          nil
        else
          GeoRuby::SimpleFeatures::Envelope.from_coordinates(
            matches[1..].map( &:to_f ).in_groups_of( 2 )
          )
        end
      end
    end
  end
end

# arel is weird and scary
module Arel
  module Nodes
    const_set( "Extent", Class.new( Function ) )
  end

  module Expressions
    def extent
      Nodes::Extent.new [self], Nodes::SqlLiteral.new( "extent" )
    end
  end

  module Visitors
    class ToSql
      # rubocop:disable Nameing/MethodName
      def visit_Arel_Nodes_Extent( obj, collector )
        collector << "St_Extent ("
        collector = visit( obj.expressions, collector ) << ")"
        if obj.alias
          collector << " AS "
          visit obj.alias, collector
        else
          collector
        end
      end
      # rubocop:enable Nameing/MethodName
    end
  end
end
