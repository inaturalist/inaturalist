class ProjectObservationRule < Rule
  def terms
    return "must be observed in #{operand.display_name}" if operator == "observed_in_place?"
    super
  end
end
