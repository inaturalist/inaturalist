module ActiveRecord
  class Base

    def self.preload_associations(instances, associations)
      ActiveRecord::Associations::Preloader.new.preload([instances].flatten, associations)
      nil
    end

  end
end
