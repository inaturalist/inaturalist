module ActiveRecord
  class Base

    def self.preload_associations(instances, associations)
      ActiveRecord::Associations::Preloader.new.preload(instances, associations)
    end

  end
end
