class ProjectObservationRule < Rule
  OPERAND_OPERATORS_CLASSES = {
    "observed_in_place?" => "Place",
    "in_taxon?" => "Taxon",
    "has_observation_field?" => "ObservationField",
    "observed_after?" => "Time",
    "observed_by_user?" => "User",
    "observed_before?" => "Time",
    "in_project?" => "Project"
  }
  OPERAND_OPERATORS = OPERAND_OPERATORS_CLASSES.keys
  
  before_save :clear_operand
  after_save :reset_last_aggregated_if_rules_changed
  after_save :touch_project
  after_destroy :reset_last_aggregated_if_rules_changed
  after_destroy :touch_project
  validate :operand_present
  validates_uniqueness_of :operator, :scope => [:ruler_type, :ruler_id, :operand_id]

  def operand_present
    if OPERAND_OPERATORS.include?(operator)
      if operand.blank? || !operand.is_a?(Object.const_get(OPERAND_OPERATORS_CLASSES[operator]))
        errors[:base] << "Must select a " + 
          OPERAND_OPERATORS_CLASSES[operator].underscore.humanize.downcase + 
          " for that rule."
      end
    end
  end
  
  def clear_operand
    return true if OPERAND_OPERATORS.include?(operator)
    self.operand = nil
    true
  end
  
  def terms
    if operator == "observed_in_place?" && operand
      "#{I18n.t(:must_be_observed_in)} #{send(:operand).display_name}"
    elsif operator == "has_observation_field?" && operand
      I18n.t(:must_have_observation_field, operand: operand.name)
    elsif operator == "observed_after?" && operand
      I18n.t(:must_be_observed_after, operand: operand.name)
    elsif operator == "observed_before?" && operand
      I18n.t(:must_be_observed_before, operand: operand.name)
    elsif operator =~ /has.+/
      thing_it_has = operator.split('_')[1..-1].join('_').gsub(/\?/, '')
      I18n.t(:must_have_x, :x => I18n.t(thing_it_has, :default => thing_it_has.humanize.downcase))
    elsif super.include? 'must be in taxon'
      taxon_rule = super.split(' taxon ')
      I18n.t("rules_types.#{taxon_rule.first.gsub(' ','_')}", default: super) + ' ' + taxon_rule.last
    else
      I18n.t("rules_types.#{super.gsub(' ','_')}", default: super)
    end
  end

  def reset_last_aggregated_if_rules_changed
    if ruler && ruler.is_a?(Project)
      ruler.update_columns(last_aggregated_at: nil)
    end
  end

  def touch_project
    if ruler && ruler.is_a?(Project)
      ruler.touch
    end
  end

end
