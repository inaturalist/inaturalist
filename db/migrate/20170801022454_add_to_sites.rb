class AddToSites < ActiveRecord::Migration
  def change
    add_column :sites, :domain, :string
    add_column :sites, :coordinate_systems_json, :text
  end
end
