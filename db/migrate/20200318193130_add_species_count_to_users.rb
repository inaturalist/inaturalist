class AddSpeciesCountToUsers < ActiveRecord::Migration
  def change
    add_column :users, :species_count, :integer, default: 0
  end
end
