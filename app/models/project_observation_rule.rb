class ProjectObservationRule < Rule
  
  def validate
    if operand.blank?
      case operator
      when "observed_in_place?"
        errors.add_to_base("Must select a place for that rule.")
      when "in_taxon?"
        errors.add_to_base("Must select a taxon for that rule.")
      end
    end
  end
  
  def terms
    return "must be observed in #{operand.display_name}" if operator == "observed_in_place?"
    super
  end
end
