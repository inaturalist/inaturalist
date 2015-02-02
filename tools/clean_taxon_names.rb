VERBOSE = true

def clean_thing(thing)
  clean_name = Taxon.remove_rank_from_name(thing.name)
  if thing.name != clean_name
    puts "\tChanging '#{thing.name}' to '#{clean_name}'" if VERBOSE
    thing.class.where(id: thing).update_all(name: clean_name)
  end
end

start_time = Time.now

puts "Creating missing taxon names (ah, data integrity)..."
taxa = Taxon.joins(:taxon_names).where(taxon_names: { id: nil })
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