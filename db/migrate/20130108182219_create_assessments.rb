class CreateAssessments < ActiveRecord::Migration
  def change
    create_table :assessments do |t|
      t.integer :taxon_id
      t.integer :project_id
      t.integer :user_id
      t.text :description
      t.datetime :completed_at

      t.timestamps
    end
  end
end
