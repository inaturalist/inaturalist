class ActiveRecord::Base
  class << self
    # Accomodates PGSQL's NULLS LAST modifier
    def reverse_sql_order(order_query)
      reversed_query = order_query.to_s.split(/,/).each { |s|
        if s.match(/\s(asc|ASC)/)
          s.gsub!(/\s(asc|ASC)/, ' DESC')
        elsif s.match(/\s(desc|DESC)/)
          s.gsub!(/\s(desc|DESC)/, ' ASC')
        elsif pos = (s =~ /\sNULLS (FIRST|LAST)$/i)
          s.insert(pos, ' DESC')
        elsif !s.match(/\s(asc|ASC|desc|DESC)$/)
          s.concat(' DESC')
        end
      }.join(',')
    end
  end
end
