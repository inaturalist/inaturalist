class AddConceptStatusToTaxa < ActiveRecord::Migration
  def self.up
    add_column :taxa, :is_active, :boolean
  end

  def self.down
    remove_column :taxa, :is_active
  end
end
