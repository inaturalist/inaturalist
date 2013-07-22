class AddDisplayOrderToAssessmentSections < ActiveRecord::Migration
  def change
    add_column :assessment_sections, :display_order, :integer
  end
end
