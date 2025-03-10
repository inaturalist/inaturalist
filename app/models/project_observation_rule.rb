# frozen_string_literal: true

class ProjectObservationRule < Rule
  OPERAND_OPERATORS_CLASSES = {
    "not_observed_in_place?" => "Place",
    "observed_in_place?" => "Place",
    "not_in_taxon?" => "Taxon",
    "in_taxon?" => "Taxon",
    "has_observation_field?" => "ObservationField",
    "observed_after?" => "Time",
    "not_observed_by_user?" => "User",
    "observed_by_user?" => "User",
    "observed_before?" => "Time",
    "in_project?" => "Project"
  }.freeze
  OPERAND_OPERATORS = OPERAND_OPERATORS_CLASSES.keys

  before_save :clear_operand
  after_save :reset_last_aggregated_if_rules_changed
  after_save :touch_projects
  after_destroy :reset_last_aggregated_if_rules_changed
  after_destroy :touch_projects
  after_create :notify_trusting_members
  after_destroy :notify_trusting_members
  validate :operand_present
  validate :ruler_must_be_a_project
  validate :umbrella_projects_only_allow_project_rules
  validates_uniqueness_of :operator, scope: [:ruler_type, :ruler_id, :operand_id]

  def operand_present
    return unless OPERAND_OPERATORS.include?( operator )
    return unless operand.blank? ||
      !operand.is_a?( Object.const_get( OPERAND_OPERATORS_CLASSES[operator] ) )

    msg = <<~MSG
      Must select a
      #{OPERAND_OPERATORS_CLASSES[operator].underscore.humanize.downcase}
      for that rule.
    MSG
    errors.add( :base, msg )
  end

  def ruler_must_be_a_project
    return if ruler.is_a?( Project )

    errors.add( :ruler_id, :must_be_a_project )
  end

  def umbrella_projects_only_allow_project_rules
    return unless ruler.is_a?( Project )
    return unless ruler.project_type == "umbrella"
    # delegated umbrella projects are allowed to have all project rules
    return if ruler.prefers_delegation
    return if operator == "in_project?"

    errors.add( :ruler_id, :umbrella_projects_only_allow_project_rules )
  end

  def clear_operand
    return true if OPERAND_OPERATORS.include?( operator )

    self.operand = nil
    true
  end

  def terms
    if operator == "observed_in_place?" && operand
      I18n.t( :must_be_observed_in_place, place: send( :operand ).display_name )
    elsif operator == "not_observed_in_place?" && operand
      I18n.t( :must_be_not_observed_in_place, place: send( :operand ).display_name )
    elsif operator == "has_observation_field?" && operand
      I18n.t( :must_have_observation_field, operand: operand.name )
    elsif operator == "observed_after?" && operand
      I18n.t( :must_be_observed_after, operand: operand.name )
    elsif operator == "observed_before?" && operand
      I18n.t( :must_be_observed_before, operand: operand.name )
    elsif operator == "observed_by_user?" && operand
      I18n.t( :must_be_observed_by_user, user: operand.login )
    elsif operator == "not_observed_by_user?" && operand
      I18n.t( :must_be_not_observed_by_user, user: operand.login )
    elsif operator == "in_taxon?" && operand
      I18n.t( :must_be_in_taxon, taxon: operand.name )
    elsif operator == "not_in_taxon?" && operand
      I18n.t( :must_be_not_in_taxon, taxon: operand.name )
    elsif operator == "in_project?" && operand
      I18n.t( :must_be_in_project, project: operand.title )
    elsif operator =~ /has.+/
      thing_it_has = operator.split( "_" )[1..].join( "_" ).gsub( /\?/, "" )
      I18n.t( :must_have_x, x: I18n.t( thing_it_has, default: thing_it_has.humanize.downcase ) )
    else
      I18n.t( "rules_types.#{super.gsub( ' ', '_' )}" )
    end
  end

  def reset_last_aggregated_if_rules_changed
    return unless ruler.is_a?( Project )

    ruler.update_columns( last_aggregated_at: nil )
  end

  def touch_projects
    return unless ruler.is_a?( Project )

    ruler.touch unless ruler.saved_change_to_id?
    return unless operand.is_a?( Project )

    operand.touch unless operand.saved_change_to_id?
  end

  def notify_trusting_members
    if ruler.prefers_user_trust?
      ruler.set_observation_requirements_updated_at( force: true )
      ruler.save
      ruler.notify_trusting_members_about_changes_later
    end
    true
  end
end
