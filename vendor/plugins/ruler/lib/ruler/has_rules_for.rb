module Ruler
  def self.included(base)
    base.send :extend, ClassMethods
  end
  
  module ClassMethods
    def has_rules_for(association)
      has_many "#{association.to_s.singularize}_rules", :class_name => "Rule", :as => :ruler
    end
    
    def validates_rules_from(association)
      validation_method_name = "validate_rules_from_#{association.to_s}"
      define_method(validation_method_name) do
        rules = send(association).send("#{self.class.to_s.underscore.singularize}_rules")
        rules.each do |rule|
          errors.add_to_base("didn't pass rule: #{rule.terms}") unless rule.validates?(self)
        end
      end
      validate validation_method_name
    end
  end
end

ActiveRecord::Base.send :include, Ruler
