# frozen_string_literal: true

class AddStatusToTaxonChanges < ActiveRecord::Migration[6.1]
  def change
    add_column :taxon_changes, :status, :string, default: "draft", null: false
  end
end
