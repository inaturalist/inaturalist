module ActiveRecord
  class Base

    def self.paginate_with_count(arel, paginate_options)
      paginate_options[:page] ||= 1
      paginate_options[:per_page] ||= 30
      offset = (paginate_options[:page].to_i - 1) * paginate_options[:per_page].to_i
      results = arel.select("#{table_name}.*, COUNT(#{table_name}.id) OVER() as total_count")
                    .limit(paginate_options[:per_page])
                    .offset(offset)
      # use [ ] here to avoid extraneous queries
      total_count = results[0] ? results[0]['total_count'] : 0
      WillPaginate::Collection.create(paginate_options[:page],
                                                      paginate_options[:per_page],
                                                      total_count) do |pager|
        pager.replace(results)
      end
    end

  end
end
