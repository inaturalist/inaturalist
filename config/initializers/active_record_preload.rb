module ActiveRecord
  class Base

    def self.preload_associations(instances, associations)
      ActiveRecord::Associations::Preloader.new.preload(instances, associations)
      nil
    end

  end
end
