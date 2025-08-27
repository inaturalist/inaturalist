# frozen_string_literal: true

class AddStatusToTaxonChanges < ActiveRecord::Migration[6.1]
  def up
    add_column :taxon_changes, :status, :string, default: "draft", null: false

    # backfill: any record with committed_on not null becomes 'committed'
    execute <<~SQL
      UPDATE taxon_changes
      SET status = 'committed'
      WHERE committed_on IS NOT NULL
    SQL
  end

  def down
    remove_column :taxon_changes, :status
  end
end
