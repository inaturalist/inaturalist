class MakePrimaryListingDefaultToTrue < ActiveRecord::Migration
  def up
    change_column :listed_taxa, :primary_listing, :boolean, :default => true
  end

  def down
    change_column :listed_taxa, :primary_listing, :boolean
  end
end
