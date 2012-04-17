class ActiveRecord::Base
  # Move has many associates from a reject to the current record.  Note this 
  # uses update_all, so you need to deal with integreity issues yourself, or 
  # in a Class.merge_duplicates method
  def merge_has_many_associations(reject)
    has_many_reflections = self.class.reflections.select{|k,v| v.macro == :has_many}
    has_many_reflections.each do |k, reflection|
      # Avoid those pesky :through relats
      next unless reflection.klass.column_names.include?(reflection.primary_key_name)
      reflection.klass.update_all(
        ["#{reflection.primary_key_name} = ?", id], 
        ["#{reflection.primary_key_name} = ?", reject.id]
      )
      if reflection.klass.respond_to?(:merge_duplicates)
        reflection.klass.merge_duplicates(reflection.primary_key_name => id)
      end
    end
  end
  
  def created_at_utc
    created_at.try(:utc) if respond_to?(:created_at)
  end
  
  def updated_at_utc
    updated_at.try(:utc) if respond_to?(:updated_at)
  end
  
  def to_json(options = {})
    options[:methods] ||= []
    options[:methods] += [:created_at_utc, :updated_at_utc]
    super(options)
  end
end
