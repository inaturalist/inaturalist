module ActiveRecord
  class Base
    # Move has many associates from a reject to the current record.  Note this 
    # uses update_all, so you need to deal with integreity issues yourself, or 
    # in a Class.merge_duplicates method
    def merge_has_many_associations(reject)
      has_many_reflections = self.class.reflections.select{|k,v| v.macro == :has_many}
      has_many_reflections.each do |k, reflection|
        # Avoid those pesky :through relats
        next unless reflection.klass.column_names.include?(reflection.foreign_key)
        
        # deal with polymorphism
        where = if reflection.type
          ["#{reflection.type} = ? AND #{reflection.foreign_key} = ?", reject.class.name, reject.id]
        else
          ["#{reflection.foreign_key} = ?", reject.id]
        end

        reflection.klass.where(where).update_all(["#{reflection.foreign_key} = ?", id])

        if reflection.klass.respond_to?(:merge_duplicates)
          reflection.klass.merge_duplicates(reflection.foreign_key => id)
        end
      end
    end
    
    def created_at_utc
      created_at.try(:utc) if has_attribute?(:created_at)
    end
    
    def updated_at_utc
      updated_at.try(:utc) if has_attribute?(:updated_at)
    end
    
    def to_json(options = {})
      options[:methods] ||= []
      options[:methods] += [:created_at_utc, :updated_at_utc]
      super(options)
    end

    def self.conditions_for_date(column, date)
      year, month, day = date.to_s.split('-').map do |d|
        d = d.blank? ? nil : d.to_i
        d == 0 ? nil : d
      end
      if date.to_s =~ /^\d{4}/ && year && month && day
        datestring = "#{year}-#{month}-#{day}"
        begin
          Date.parse(datestring)
          ["#{column}::DATE = ?", datestring]
        rescue ArgumentError => e
          raise e unless e.message =~ /invalid date/
          "1 = 2"
        end
      elsif year || month || day
        conditions, values = [[],[]]
        if year
          conditions << "EXTRACT(YEAR FROM #{column}) = ?"
          values << year
        end
        if month
          conditions << "EXTRACT(MONTH FROM #{column}) = ?"
          values << month
        end
        if day
          conditions << "EXTRACT(DAY FROM #{column}) = ?"
          values << day
        end
        [conditions.join(' AND '), *values]
      else
        "1 = 2"
      end
    end
  end

  # MONKEY PATCH
  # This should be fixed in future versions of Rails: https://github.com/rails/rails/commit/59c4b22c4528e9f97d3eb394f603dc50c3cf41a9
  module ConnectionAdapters
    class PostgreSQLAdapter
      def distinct(columns, orders) #:nodoc:
        return "DISTINCT #{columns}" if orders.empty?

        # Construct a clean list of column names from the ORDER BY clause, removing
        # any ASC/DESC modifiers
        order_columns = orders.collect { |s| s.gsub(/\s+(ASC|DESC)\s*(NULLS\s+(FIRST|LAST)\s*)?/i, '') }
        order_columns.delete_if { |c| c.blank? }
        order_columns = order_columns.zip((0...order_columns.size).to_a).map { |s,i| "#{s} AS alias_#{i}" }

        "DISTINCT #{columns}, #{order_columns * ', '}"
      end
    end
  end

  # MONKEY PATCH
  # pluck_all selects just the columns needed and constructs a hash with their values
  # In rails 4, this is a feature of the "pluck" itself (the ability to take multiple argumetns)
  # In theory, this method could overwrite "pluck," but that seems a bit aggressive 
  # Details on pluck_all are here: http://meltingice.net/2013/06/11/pluck-multiple-columns-rails/
  class Relation
    def pluck_all(*args)
      args.map! do |column_name|
        if column_name.is_a?(Symbol) && column_names.include?(column_name.to_s)
          "#{connection.quote_table_name(table_name)}.#{connection.quote_column_name(column_name)}"
        else
          column_name.to_s
        end
      end

      relation = clone
      relation.select_values = args
      klass.connection.select_all(relation.arel).map! do |attributes|
        initialized_attributes = klass.initialize_attributes(attributes)
        attributes.each do |key, attribute|
          attributes[key] = klass.type_cast_attribute(key, initialized_attributes)
        end
      end
    end
  end
end
