class AddSlugsToPlaces < ActiveRecord::Migration
  def change
    add_column :places, :slug, :string
    add_index  :places, :slug, :unique => true
  end
end
