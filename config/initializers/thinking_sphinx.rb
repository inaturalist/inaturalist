# Monkey patches for TS

# Hardcode compatability with RGeo's postgis adapter
module ThinkingSphinx::ActiveRecord::DatabaseAdapters
  class << self
    def adapter_for(model)
      return default.new(model) if default
      PostgreSQLAdapter.new model
    end

    def adapter_type_for(model)
      :postgresql
    end
  end
end
