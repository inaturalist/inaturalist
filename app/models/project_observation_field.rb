class ProjectObservationField < ActiveRecord::Base
  belongs_to :project, :inverse_of => :project_observation_fields
  belongs_to :observation_field, :inverse_of => :project_observation_fields
  validates :project, :presence => true
  validates :observation_field, :presence => true

  after_save :create_project_rule
  after_destroy :destroy_project_rule

  def create_project_rule
    project.project_observation_rules.create(
      :operator => "has_observation_field?", 
      :operand => observation_field)
    true
  end

  def destroy_project_rule
    project.project_observation_rules.where(
      :operator => "has_observation_field?", 
      :operand_type => "ObservationField",
      :operand_id => observation_field_id
    ).each(&:destroy)
    true
  end
end
