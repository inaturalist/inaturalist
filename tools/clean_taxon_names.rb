VERBOSE = true

def clean_thing(thing)
  clean_name = Taxon.remove_rank_from_name(thing.name)
  if thing.name != clean_name
    puts "\tChanging '#{thing.name}' to '#{clean_name}'" if VERBOSE
    thing.class.update_all(["name = ?", clean_name], ["id = ?", thing])
  end
end

start_time = Time.now

puts "Creating missing taxon names (ah, data integrity)..."
taxa = Taxon.all(:include => :taxon_names, :conditions => "taxon_names.id is null")
taxa.each(&:save)
puts "\tSaved #{taxa.size} new taxon names."

puts "Cleaning taxon_names..."
TaxonName.find_each(:include => :taxon, :conditions => {:lexicon => TaxonName::LEXICONS[:SCIENTIFIC_NAMES]}) do |tn|
  clean_thing(tn)
end

puts "Cleaning taxa..."
Taxon.find_each do |taxon|
  clean_thing(taxon)
end

puts
puts "Comleted in #{Time.now - start_time} seconds"