# frozen_string_literal: true

class CreateTaxonIdSummaries < ActiveRecord::Migration[6.1]
  def up
    create_table :taxon_id_summaries do | t |
      t.string     :uuid
      t.boolean    :active, default: false
      t.integer    :taxon_id
      t.string     :taxon_name
      t.string     :taxon_common_name
      t.integer    :taxon_photo_id
      t.string     :taxon_group
      t.string     :run_name
      t.datetime   :run_generated_at
      t.text       :run_description
      t.timestamps
    end

    # Enforce only one active run at a time
    execute <<~SQL
      CREATE UNIQUE INDEX idx_taxon_id_summaries_active_per_taxon
      ON taxon_id_summaries (taxon_id)
      WHERE active = TRUE
    SQL
  end

  def down
    execute "DROP INDEX IF EXISTS idx_taxon_id_summaries_active_per_taxon"
    drop_table :taxon_id_summaries
  end
end
