class AddParameterizedLexiconToTaxonNames < ActiveRecord::Migration
  def up
    add_column :taxon_names, :parameterized_lexicon, :string
    say <<-EOT
You will need to migrate the data after updating the schema:
TaxonName.uniq.where.not(lexicon: nil).pluck(:lexicon).each do |l|
  next unless l.parameterize.present?
  TaxonName.where(lexicon: l).update_all(parameterized_lexicon: l.parameterize)
end
    EOT
  end
  
  def down
    remove_column :taxon_names, :parameterized_lexicon
  end
end
