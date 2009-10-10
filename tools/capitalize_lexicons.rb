# Make sure all lexicons are capitalized
TaxonName::LEXICONS.each do |key, lexicon|
  puts "Capitalizing '#{lexicon}'..."
  TaxonName.update_all(["lexicon = ?", lexicon], ["lexicon = ?", lexicon.downcase])
end
