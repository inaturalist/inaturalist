class AddLanguageToTaxonIdSummaries < ActiveRecord::Migration[6.1]
  def change
    add_column :taxon_id_summaries, :language, :string, null: false, default: "en"

    remove_index :taxon_id_summaries, name: "idx_taxon_id_summaries_active_per_taxon"
    add_index :taxon_id_summaries,
      [:taxon_id, :language],
      unique: true,
      where: "active = true",
      name: "idx_taxon_id_summaries_active_per_taxon"
  end
end
