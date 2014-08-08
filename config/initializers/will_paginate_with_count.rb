module WillPaginate
  module ActiveRecord

    module RelationMethods

      attr_accessor :postresql_count_over

      def to_a
        if current_page.nil? then super # workaround for Active Record 3.0
        else
          forced_total = build_arel.to_sql.match(/COUNT\(.*?\) OVER\(\)/) ? 1 : nil
          ::WillPaginate::Collection.create(current_page, limit_value, forced_total) do |col|
            col.replace super
            col.total_entries ||= total_entries
          end
        end
      end

    end

    module Pagination

      def paginate_with_count_over(options)
        pager = paginate(options.merge(select: "#{table_name}.*, COUNT(#{table_name}.id) OVER() as total_count"))
        # use [ ] here to avoid extraneous queries
        pager.total_entries = pager[0] ? pager[0]['total_count'].to_i : 0
        pager
      end

    end
  end
end
