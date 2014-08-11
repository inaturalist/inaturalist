module WillPaginate
  module ActiveRecord

    module RelationMethods

      attr_accessor :postresql_count_over

      def to_a
        if current_page.nil? then super # workaround for Active Record 3.0
        else
          using_count_over = build_arel.to_sql.match(/COUNT\(.*?\) OVER\(\)/)
          ::WillPaginate::Collection.create(current_page, limit_value, using_count_over ? 1 : nil) do |col|
            col.replace super
            if using_count_over
              @total_entries = col.first ? col.first['total_count'].to_i : 0
              col.total_entries = @total_entries
            else
              col.total_entries ||= total_entries
            end
          end
        end
      end

    end

    module Pagination

      def paginate_with_count_over(options)
        paginate(options.merge(select: "#{table_name}.*, COUNT(#{table_name}.id) OVER() as total_count"))
      end

    end
  end
end
