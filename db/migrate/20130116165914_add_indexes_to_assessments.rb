class AddIndexesToAssessments < ActiveRecord::Migration
  def change
    add_index :assessments, :project_id
    add_index :assessments, :taxon_id
    add_index :assessments, :user_id

    add_index :assessment_sections, :user_id
    add_index :assessment_sections, :assessment_id
  end
end
