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
        Rails.logger.debug "[DEBUG] merging associates for #{k}"
        begin
          self.class.connection.transaction do
            reflection.klass.where(where).update_all(["#{reflection.foreign_key} = ?", id])
          end
        rescue ActiveRecord::RecordNotUnique => e
        end

        if reflection.klass.respond_to?(:merge_duplicates)
          reflection.klass.merge_duplicates(reflection.foreign_key => id)
        end
      end

      # ensure the reject no longer has any of its associates hanging around in memory
      reject.reload
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
      if date == 'today'
        return ["#{column} >= ? AND #{column} < ?", Date.today.to_s, Date.tomorrow.to_s]
      end
      begin
        conditions = nil
        if d = split_date(date)
          conditions = extract_date_ranges(column, d[:year], d[:month], d[:day]) ||
            extract_date_conditions(column, d[:year], d[:month], d[:day])
        end
      rescue ArgumentError => e
        raise e unless e.message =~ /invalid date/
      end
      conditions || "1 = 2"
    end

    def self.split_date(date, options={})
      return unless date
      # we expect date to be a date, time or string object
      date_copy = date.is_a?(Fixnum) ? date.to_s : date.dup
      if date_copy.is_a?(String) && date_copy == "today"
        date_copy = Time.now
      end
      date_copy = date_copy.utc if date_copy.is_a?(Time) && options[:utc]
      if date_copy.is_a?(Date) || date_copy.is_a?(Time)
        { year: date_copy.year, month: date_copy.month, day: date_copy.day }
      elsif date_copy.is_a?(String)
        year, month, day = date_copy.to_s.split('-').map do |d|
          d = d.blank? ? nil : d.to_i
          d == 0 ? nil : d
        end
        { year: year, month: month, day: day }
      end
    end

    def self.extract_date_ranges(column, year, month, day)
      if year && month && day
        date = Date.parse("#{ year }-#{ month }-#{ day }")
        [ "#{column} >= ? AND #{column} < ?", date, date + 1.day ]
      elsif year && month && !day
        date = Date.parse("#{ year }-#{ month }-1")
        [ "#{column} >= ? AND #{column} < ?", date, date + 1.month ]
      elsif year && !month && !day
        date = Date.parse("#{ year }-1-1")
        [ "#{column} >= ? AND #{column} < ?", date, date + 1.year ]
      end
    end

    def self.extract_date_conditions(column, year, month, day)
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

  class ActiveRecord::ConnectionAdapters::PostGISAdapter::MainAdapter
    def active_queries
      User.connection.execute("SELECT * FROM pg_stat_activity WHERE state = 'active' ORDER BY state_change ASC").
        to_a.delete_if{ |r| r["query"] =~ /SELECT \* FROM pg_stat_activity/ }
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
