module Ruler
  def self.included(base)
    base.send :extend, ClassMethods
  end
  
  module ClassMethods
    def has_rules_for(association, options = {})
      rule_class = options[:rule_class] || Rule
      association_name = "#{association.to_s.singularize}_rules".to_sym
      has_many association_name, :class_name => rule_class.to_s, :as => :ruler
      accepts_nested_attributes_for association_name, :allow_destroy => true, 
        :reject_if => :all_blank
    end
    
    def validates_rules_from(association, options = {})
      validation_method_name = "validate_rules_from_#{association.to_s}"
      define_method(validation_method_name) do
        return if send(association).blank?
        rules = send(association).send("#{self.class.to_s.underscore.singularize}_rules")
        rules.each do |rule|
          errors.add_to_base("Didn't pass rule: #{rule.terms}") unless rule.validates?(self)
        end
      end
      validate validation_method_name
      
      const_set "RULE_METHODS", options[:rule_methods] || []
    end
  end
end

ActiveRecord::Base.send :include, Ruler
