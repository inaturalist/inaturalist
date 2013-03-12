class AddUrlToTaxonRanges < ActiveRecord::Migration
  def change
    add_column :taxon_ranges, :url, :string
  end
end
