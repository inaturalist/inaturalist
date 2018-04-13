class CreateControlledTermTaxa < ActiveRecord::Migration
  def up
    create_table :controlled_term_taxa do |t|
      t.integer :controlled_term_id
      t.integer :taxon_id
      t.boolean :exception, default: false
    end
    add_index :controlled_term_taxa, :controlled_term_id
    add_index :controlled_term_taxa, :taxon_id
    ControlledTerm.find_each do |ct|
      if ct.valid_within_clade
        ControlledTermTaxon.create( controlled_term_id: ct.id, taxon_id: ct.valid_within_clade )
      end
    end
    ControlledTerm.elastic_index!
  end

  def down
    drop_table :controlled_term_taxa
  end
end
