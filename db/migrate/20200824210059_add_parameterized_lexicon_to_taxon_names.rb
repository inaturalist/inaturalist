class AddParameterizedLexiconToTaxonNames < ActiveRecord::Migration
  def up
    add_column :taxon_names, :parameterized_lexicon, :string
    
    # Backfill Parameterized Lexicon
    TaxonName.uniq.where.not(lexicon: nil).pluck(:lexicon).each do |l|
      next unless l.parameterize.present?

      TaxonName.where(lexicon: l).update_all(parameterized_lexicon: l.parameterize)
    end
  end
  
  def down
    remove_column :taxon_names, :parameterized_lexicon
  end
end
