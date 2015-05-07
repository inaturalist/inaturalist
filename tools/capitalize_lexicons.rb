# Make sure all lexicons are capitalized
TaxonName::LEXICONS.each do |key, lexicon|
  puts "Capitalizing '#{lexicon}'..."
  TaxonName.where(lexicon: lexicon.downcase).update_all(lexicon: lexicon)
end
