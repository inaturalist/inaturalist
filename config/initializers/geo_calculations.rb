module ActiveRecord
  module Calculations
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
  end
end

# arel is weird and scary
module Arel
  module Nodes
    const_set("Extent", Class.new(Function))
  end

  module Expressions
    def extent
      Nodes::Extent.new [self], Nodes::SqlLiteral.new('extent')
    end
  end

  module Visitors
    class ToSql
      def visit_Arel_Nodes_Extent(o, collector)
        collector << "St_Extent ("
        collector = visit(o.expressions, collector) << ")"
        if o.alias
          collector << " AS "
          visit o.alias, collector
        else
          collector
        end
      end
    end
  end
end
