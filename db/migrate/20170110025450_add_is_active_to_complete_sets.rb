class AddIsActiveToCompleteSets < ActiveRecord::Migration
  def change
    add_column :complete_sets, :is_active, :boolean, default: false
  end
end
