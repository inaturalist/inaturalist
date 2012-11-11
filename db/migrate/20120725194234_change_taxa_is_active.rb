class ChangeTaxaIsActive < ActiveRecord::Migration
  def self.up
  	Taxon.update_all({:is_active => false}, "is_active IS NULL")
  	change_column :taxa, :is_active, :boolean, :null => false, :default => true
  end

  def self.down
  	change_column :taxa, :is_active, :boolean, :null => true, :default => nil
  end
end
