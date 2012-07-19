class MakeTaxaIsActiveDefaultTrue < ActiveRecord::Migration
  def self.up
    change_column :taxa, :is_active, :boolean, :default => true
  end

  def self.down
    change_column :taxa, :is_active, :boolean, :default => nil
  end
end
