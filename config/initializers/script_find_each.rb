module ActiveRecord
  module Batches
    # Just like find_each except it writes useful output to STDOUT
    def script_find_each(options = {})
      total = self.count
      current = 1
      find_each(options) do |record|
        puts ["#{record.class.name} #{record.id}", "#{current.to_s.rjust(10)} / #{total}", "#{(current.to_f / total * 100).round(2)}%"].join("\t")
        current += 1
        yield record
      end
    end
  end

  module Querying
    delegate :script_find_each, to: :all
  end
end
