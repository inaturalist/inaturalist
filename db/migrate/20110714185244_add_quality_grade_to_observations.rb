class AddQualityGradeToObservations < ActiveRecord::Migration
  def self.up
    add_column :observations, :quality_grade, :string, :default => "casual"
    add_index :observations, :quality_grade
  end

  def self.down
    remove_column :observations, :quality_grade
  end
end
