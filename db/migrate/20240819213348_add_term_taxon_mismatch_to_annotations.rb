# frozen_string_literal: true

class AddTermTaxonMismatchToAnnotations < ActiveRecord::Migration[6.1]
  def change
    add_column :annotations, :term_taxon_mismatch, :boolean, default: false
  end
end
