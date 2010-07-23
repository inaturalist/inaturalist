class RemoveLftFromListedTaxa < ActiveRecord::Migration
  def self.up
    remove_column :listed_taxa, :lft
  end

  def self.down
    add_column :listed_taxa, :lft, :integer
  end
end
