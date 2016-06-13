class DropIndexOnTaxonName < ActiveRecord::Migration
  def up
    remove_index :taxa, :name
  end
  def down
    add_index :taxa, :name
  end
end
