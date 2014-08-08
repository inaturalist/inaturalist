module ActiveRecord
  class Base

    def self.preload_associations(instances, associations, preload_options = {})
      ActiveRecord::Associations::Preloader.new(instances, associations, preload_options).run
    end

  end
end
