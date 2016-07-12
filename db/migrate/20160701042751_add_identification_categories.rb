class AddIdentificationCategories < ActiveRecord::Migration
  def change
    add_column :identifications, :category, :string
    add_index :identifications, :category
  end
end
