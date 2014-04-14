require 'rubygems'
require 'trollop'

opts = Trollop::options do
    banner <<-EOS
Create and/or sync CA county/family lists from Calflora

Usage:
  rails runner tools/sync_calflora_lists.rb

Options:
EOS
  opt :debug, "Print debug statements", :type => :boolean, :short => "-d"
  opt :test, "Don't actually touch the db", :short => "-t", :type => :boolean
end

OPTS = opts
puts "[DEBUG] OPTS: #{OPTS.inspect}"

# taxon_source = Source.find_by_title("Jepson Manual II")
taxon_source = Source.find_by_title("Calflora")
taxon_source ||= Source.create(
  # :title => "Jepson Manual II",
  # :in_text => "Baldwin et al. 2011",
  # :url => "http://ucjeps.berkeley.edu/taxon_sourcemanual/review/",
  # :citation => "Baldwin et al. (eds.). 2011. Jepson Manual II: Vascular Plants of California. Univ. of California Press, Berkeley."
  :in_text => "Calflora #{Time.now.year}",
  :citation => "Calflora: Information on California plants for education, research and conservation. [web application]. #{Time.now.year}. Berkeley, California: The Calflora Database [a non-profit organization]. Available: http://www.calflora.org/ (Accessed: #{Time.now.strftime('%M %d, %Y')}).",
  :url => "http://www.calflora.org/",
  :title => "Calflora"
)
# taxon_scheme = TaxonScheme.find_by_title("Jepson Manual II")
# taxon_scheme ||= TaxonScheme.create(
#   :title => "Jepson Manual II",
#   :source => taxon_source
# )
taxon_scheme = TaxonScheme.find_by_title("Calflora")
taxon_scheme ||= TaxonScheme.create(
  :title => "Calflora",
  :source => taxon_source
)
TAXON_SOURCE = taxon_source
TAXON_SCHEME = taxon_scheme

def work_on_place(place)
  puts "Working on #{place}..."
  start_time = Time.now
  # self_and_ancestor_ids = [taxon.ancestor_ids, taxon.id].flatten.join('/')
  # check_list = place.check_lists.build(:taxon => taxon)
  
  # unless check_list.save
  #   puts "Failed to create checklist for #{place}: #{check_list.errors.full_messages.to_sentence}"
  #   next
  # end
  # ListedTaxon.update_all(
  #   "list_id = #{check_list.id}", 
  #   ["list_id = #{place.check_list_id} AND taxon_ancestor_ids LIKE ?", "#{self_and_ancestor_ids}/%"])
  # puts "Created list of #{taxon.name} for #{place.display_name} #{check_list}"

  name = place.name.gsub(/\s*county\s+/i, '').capitalize
  url = "http://www.calflora.org/cgi-bin/specieslist.cgi?where-prettyreglist=#{name}&output=text"
  agent = Mechanize.new
  page = agent.get(url)
  names = page.body.split("\n")[1..-1]
  if names.blank?
    puts "\tERROR: no names for #{url}, skipping..."
    return
  end

  source = Source.find_by_url(url)
  source ||= Source.create(
    :in_text => "Calflora #{Time.now.year}",
    :citation => "Calflora: Information on California plants for education, research and conservation. [web application]. #{Time.now.year}. Berkeley, California: The Calflora Database [a non-profit organization]. Available: http://www.calflora.org/ (Accessed: #{Time.now.strftime('%M %d, %Y')}).",
    :url => url,
    :title => "Calflora Plant Search Results, county: #{name}"
  )

  skipped_names = []
  invalid_names = []
  lists = []
  names.each do |name|
    puts "\tWorking on #{name}..."
    taxon = Taxon.single_taxon_for_name(name, :ancestor => Taxon::ICONIC_TAXA_BY_NAME['Plantae'])
    taxon ||= Taxon.where(:name => Taxon.remove_rank_from_name(name)).
      where(Taxon::ICONIC_TAXA_BY_NAME['Plantae'].descendant_conditions).
      first
    taxon ||= find_external_taxon_for(name)
    taxon ||= create_new_taxon_for(name)
    unless taxon
      puts "\t\tCouldn't find taxon for #{name}, skipping..."
      skipped_names << name
      next
    end
    taxon.taxon_schemes << TAXON_SCHEME unless taxon.taxon_schemes.include?(TAXON_SCHEME)
    list = find_or_create_list_for(taxon, place, :source => source)
    unless list
      puts "\t\tCouldn't find list for #{taxon}, skipping..."
      skipped_names << name
      next
    end
    lists << list unless lists.include?(list)
    if existing_lt = place.check_list.listed_taxa.where(:taxon_id => taxon.id).first
      puts "\t\tFound existing lt: #{existing_lt}, moving to new list"
      existing_lt.update_attributes(:list => list) unless OPTS[:test]
    else
      puts "\t\tAdding #{taxon} to #{list}"
      lt = unless OPTS[:test]
        list.add_taxon(taxon, :source => source, :skip_sync_with_parent => true, :force_update_cache_columns => true)
      end
      if lt && !lt.valid?
        puts "\t\t\tFailed to add #{lt}: #{lt.errors.full_messages.to_sentence}"
        invalid_names << name
      end
    end
  end

  lists.each do |list|
    make_list_comprehensive(list)
  end
  puts "Finished #{place}, skipped #{skipped_names.size} names, #{invalid_names.size} invalid names, #{Time.now - start_time} s"
  puts "Skipped names:"
  skipped_names.each do |name|
    puts name
  end
  puts "\n\n"
end

def find_external_taxon_for(name)
  taxon = nil
  puts "\t\t\tSearching external providers for #{name}..."
  if matches = ratatosk.find(name)
    puts "\t\t\tFound #{matches.size} matches"
    if !OPTS[:test] && taxon_name = matches.detect{|m| m.name == name}
      puts "\t\t\tSaving #{taxon_name}"
      if taxon_name.save
        taxon = taxon_name.taxon
        if taxon.valid? && !taxon.new_record?
          taxon.graft(:ancestor => Taxon::ICONIC_TAXA_BY_NAME['Plantae'])
        else
          puts "\t\t\ttaxon invalid: #{taxon.errors.full_messages.to_sentence}"
          taxon = nil
        end
      else
        puts "\t\t\ttaxon name invalid: #{taxon_name.errors.full_messages.to_sentence}"
      end
    end
  end
  if taxon && taxon.grafted?
    taxon
  else
    nil
  end
rescue Timeout::Error => e
  puts "\t\t\tTimed out, skipping"
  nil
end

def create_new_taxon_for(name)
  t = Taxon.new(:name => name)
  t.source = TAXON_SOURCE
  t.rank = if name =~ /ssp\./
    Taxon::SUBSPECIES
  elsif name =~ /var\./
    Taxon::VARIETY
  elsif name =~ /^[A-Z][a-z]+\s+X[a-z]+$/
    Taxon::HYBRID
  else
    Taxon::SPECIES
  end
  if t.hybrid?
    t.name = t.name.gsub(/\sX/, " × ")
    t.taxon_names.build(
      :name => name, 
      :taxon => t,
      :source => TAXON_SOURCE, 
      :is_valid => false, 
      :lexicon => TaxonName::SCIENTIFIC_NAMES)

  end
  unless OPTS[:test]
    if t.save
      t.graft(:ancestor => Taxon::ICONIC_TAXA_BY_NAME['Plantae'])
    else
      puts "\t\t\tFailed to save #{t}: #{t.errors.full_messages}"
      t.taxon_names.each do |tn|
        puts "\t\t\t#{tn} invalid: #{tn.errors.full_messages}"
      end
    end
    # TAXON_SCHEME.taxa << t
  end
  t
end

def find_or_create_list_for(taxon, place, options = {})
  return nil unless family = taxon.family
  list = place.check_lists.where(:taxon_id => family.id, :source_id => options[:source]).first
  list ||= place.check_lists.build(:taxon => family, :title => "#{family.name} of #{place.display_name}")
  list.source = options[:source]
  list.save if list.new_record? && !OPTS[:test]
  puts "\t\tFound or created list: #{list}"
  list
end

def make_list_comprehensive(list)
  puts "\tMaking #{list} comprehensive..."
  list.update_attributes(:comprehensive => true) unless OPTS[:test]
end

california = Place.where(:name => "California", :place_type => Place::PLACE_TYPE_CODES["State"]).first
california.children.where(:place_type => Place::PLACE_TYPE_CODES["County"]).find_each do |county|
  work_on_place(county)
end
