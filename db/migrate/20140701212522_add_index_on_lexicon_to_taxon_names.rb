class AddIndexOnLexiconToTaxonNames < ActiveRecord::Migration
  def up
    # add_index :taxon_names, :lexicon
    execute <<-SQL
      CREATE INDEX taxon_names_lower_lexicon_index ON taxon_names (lower(lexicon));
    SQL
  end

  def down
    remove_index :taxon_names, :name => "taxon_names_lower_lexicon_index"
  end
end
