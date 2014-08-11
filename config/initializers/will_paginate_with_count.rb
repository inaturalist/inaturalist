module WillPaginate
  module ActiveRecord

    module RelationMethods

      # this method is an overried to the built in .to_a method
      # See https://github.com/mislav/will_paginate/blob/master/lib/will_paginate/active_record.rb
      def to_a
        if current_page.nil? then super # workaround for Active Record 3.0
        else
          ::WillPaginate::Collection.create(current_page, limit_value) do |col|
            col.replace super
            # this conditional is the change. When we recognize PostgreSQL's
            # COUNT() OVER(), make sure the default total_entries method is not
            # called as that will initiate a new COUNT() query. Just grab the
            # count from the first result (all results have a total_count attribute).
            # Be sure to also set the ActiveRecord::Relation @total_entries
            if build_arel.to_sql.match(/COUNT\(.*?\) OVER\(\) as total_count/)
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

      # this new method will send to .paginate the options as well as a select
      # option which uses PostreSQL's COUNT() OVER() methods. This will allow
      # for fetching the page of results while simultaneously counting the
      # total entries
      def paginate_with_count_over(options)
        paginate(options.merge(select: "#{table_name}.*, COUNT(#{table_name}.id) OVER() as total_count"))
      end

    end
  end
end
