class AddSourceIdentifierToGuideTaxon < ActiveRecord::Migration
  def change
    add_column :guide_taxa, :source_identifier, :string
  end
end
