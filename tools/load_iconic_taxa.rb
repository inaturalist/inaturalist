#
# Creates taxa and names for all the iconic taxa.  This is to get a blank db
# up to speed.
#
# Run this with script/runner!
#

iconic_taxa = {}
puts "Adding Life"
life = Taxon.create(
  :name => "Life", 
  :rank => 'none', 
  :source => Source.find_by_title('iNaturalist'))
life.iconic_taxon = life
life.save

#scientific,common
iconic_taxa_names = [
  ['Animalia', 'Animals'],
  ['Actinopterygii', 'Ray-finned Fishes'],
  ['Aves', 'Birds'],
  ['Reptilia', 'Reptiles'],
  ['Amphibia', 'Amphibians'],
  ['Mammalia', 'Mammals'],
  ['Arachnida', 'Arachnids'],
  ['Insecta', 'Insects'],
  ['Plantae', 'Plants'],
  ['Fungi', 'Fungi'],
  ['Protozoa', 'Protozoans'],
  ['Mollusca', 'Mollusks'],
  ['Chromista', 'Chromista']
]

# Make sure we graft from CoL
ratatosk = Ratatosk::Ratatosk.new(
  :name_providers => [Ratatosk::NameProviders::ColNameProvider.new])


iconic_taxa_names.each do |iconic_taxon_name|
  puts "Adding #{iconic_taxon_name[0]}..."
  taxon_name = ratatosk.find(iconic_taxon_name[0]).first
  puts "\tMaking the taxon iconic..."
  taxon_name.taxon.is_iconic = 1
  puts "\tSaving the taxon..."
  taxon_name.save
  taxon_name.reload
  puts "\tGrafting..."
  ratatosk.graft(taxon_name.taxon)
  iconic_taxa[iconic_taxon_name[0].to_sym] = taxon_name.taxon
  puts "\tAdding Common Name..."
  TaxonName.new(
    :taxon => Taxon.find_by_name(iconic_taxon_name[0]), 
    :name => iconic_taxon_name[1], 
    :lexicon => 'english', 
    :is_valid => 1).save
end
