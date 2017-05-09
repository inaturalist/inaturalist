class ProjectObservationField < ActiveRecord::Base
  belongs_to :project, :inverse_of => :project_observation_fields
  belongs_to :observation_field, :inverse_of => :project_observation_fields
  validates :project, :presence => true
  validates :observation_field, :presence => true

  after_save :update_project_rule
  after_destroy :destroy_project_rule

  def update_project_rule
    required ? create_project_rule : destroy_project_rule
  end

  def create_project_rule
    return true unless required?
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

  def as_indexed_json(options={})
    return {
      id: id,
      required: required,
      observation_field: observation_field.as_indexed_json,
      position: position
    }
  end

  def self.default_json_options
    {
      :methods => [:created_at_utc, :updated_at_utc],
      :include => {
        :observation_field => ObservationField.default_json_options
      }
    }
  end
end
