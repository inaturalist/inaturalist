module Ruler
  def self.included(base)
    base.send :extend, ClassMethods
  end
  
  module ClassMethods
    def has_rules_for(association, options = {})
      rule_class = options[:rule_class] || Rule
      association_name = "#{association.to_s.singularize}_rules".to_sym
      has_many association_name, class_name: rule_class.to_s, as: :ruler, dependent: :destroy
      accepts_nested_attributes_for association_name, :allow_destroy => true, 
        :reject_if => :all_blank
    end
    
    def validates_rules_from(association, options = {})
      validation_method_name = "validate_rules_from_#{association.to_s}"
      rule_methods = options.delete(:rule_methods) || []
      define_method(validation_method_name) do
        return if send(association).blank?
        rules = send(association).send("#{self.class.to_s.underscore.singularize}_rules")
        rules.group_by(&:operator).each do |operator, operator_rules|
          errors_for_operator = []
          operator_rules.each do |rule|
            if rule.validates?(self)
              # since only one of the group needs to pass, we can stop
              break
            else
              errors_for_operator << rule.terms
            end
          end
          next if errors_for_operator.blank?
          if operator_rules.size == 1
            errors[:base] << "Didn't pass rule: #{errors_for_operator.first}"
          # FYI: if there are multiple rules with the same operator
          # ONLY ONE of the rules with that operator must pass. For example
          # if there are 10 place rules, the obs needs be in only 1
          elsif errors_for_operator.size == operator_rules.size
            errors[:base] << "Didn't pass rules: #{errors_for_operator.join(' OR ')}"
          end
        end
      end
      validate validation_method_name, options
      
      const_set "RULE_METHODS", rule_methods
    end
  end
end

ActiveRecord::Base.send :include, Ruler
