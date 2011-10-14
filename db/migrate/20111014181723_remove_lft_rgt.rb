class RemoveLftRgt < ActiveRecord::Migration
  def self.up
    remove_column :taxa, :lft
    remove_column :taxa, :rgt
  end

  def self.down
    add_column :taxa, :lft, :integer
    add_column :taxa, :rgt, :integer
  end
end
