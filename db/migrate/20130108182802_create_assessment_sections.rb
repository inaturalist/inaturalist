class CreateAssessmentSections < ActiveRecord::Migration
  def change
    create_table :assessment_sections do |t|
      t.integer :assessment_id
      t.integer :user_id
      t.string :title
      t.text :body

      t.timestamps
    end
  end
end
