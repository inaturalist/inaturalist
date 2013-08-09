class AddShortTitleToTaxonLinks < ActiveRecord::Migration
  def change
  	add_column :taxon_links, :short_title, :string, :limit => 10
  end
end
