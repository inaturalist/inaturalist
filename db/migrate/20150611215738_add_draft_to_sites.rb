class AddDraftToSites < ActiveRecord::Migration
  def change
    add_column :sites, :draft, :boolean, default: false
  end
end
