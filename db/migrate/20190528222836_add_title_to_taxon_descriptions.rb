class AddTitleToTaxonDescriptions < ActiveRecord::Migration
  def change
    add_column :taxon_descriptions, :title, :string
  end
end
