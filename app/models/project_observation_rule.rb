class ProjectObservationRule < Rule
  
  def validate
    if operator == "observed_in_place?"
      if operand.blank?
        errors.add_to_base "Must select a place for that rule."
      end
    end
  end
  
  def terms
    return "must be observed in #{operand.display_name}" if operator == "observed_in_place?"
    super
  end
end
