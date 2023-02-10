class RemoveTaxaUniqueName < ActiveRecord::Migration[6.1]
  def up
    remove_column :taxa, :unique_name
  end

  def down
    add_column :taxa, :unique_name, :string
    add_index :taxa, :unique_name, unique: true
  end
end
