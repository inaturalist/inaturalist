require "rubygems"
require "optimist"

opts = Optimist::options do
    banner <<-EOS
Import / update NatureServe conservation statuses.

Usage:

  rails runner tools/natureserve_statuses.rb [OPTIONS]

Examples:
  
  # Import statuses for all species in Accipiter
  rails r tools/natureserve_statuses.rb -t Accipiter

  # Import statuses for all species in Accipiter and make new taxon records
  # when necessary
  rails r tools/natureserve_statuses.rb -ct Accipiter

  # Import statuses for Accipiter gentilis and its descendants. The ancestor
  # param doesn't take strings with spaces, but it will take any string that
  # will have spaces after calling `humanize`
  rails r tools/natureserve_statuses.rb -ct Accipiter_gentilis

where [options] are:
EOS
  opt :debug, "Print debug statements", :type => :boolean, :short => "-d"
  opt :ancestor, "Ancestor taxon", :type => :string, :short => "-t"
  opt :create_taxa, "Create taxa that don't exist.", :type => :boolean, :short => "-c"
  opt :place, "Only create statuses for this place. Can be a place ID or slug.", type: :string, short: "-p"
  opt :min_id, "Minimum taxon id", :type => :integer
  opt :max_id, "Maximum taxon id", :type => :integer
  opt :api_key, "NatureServe API key", :type => :string, :short => "-k"
end

start = Time.now

OPTS = opts
KEY = OPTS.api_key || CONFIG.natureserve.key

if source = Source.find_by_title('NatureServe')
  SOURCE = source
else
  SOURCE = Source.create(
    :title => "NatureServe",
    :in_text => "NatureServe, 2013",
    :citation => "Natureserve. 2013. NatureServe Web Service. Arlington, VA. U.S.A. Available http://services.natureserve.org. (Accessed: 2013)",
    :url => "http://services.natureserve.org"
  )
end

PLACE = Place.find( OPTS.place ) rescue nil

IUCN_NOT_EVALUATED = 0
IUCN_DATA_DEFICIENT = 5
IUCN_LEAST_CONCERN = 10
IUCN_NEAR_THREATENED = 20
IUCN_VULNERABLE = 30
IUCN_ENDANGERED = 40
IUCN_CRITICALLY_ENDANGERED = 50
IUCN_EXTINCT_IN_THE_WILD = 60
IUCN_EXTINCT = 70

def rank2iucn(rank)
  case rank[1]
  when "X" then Taxon::IUCN_EXTINCT
  when "H" then Taxon::IUCN_CRITICALLY_ENDANGERED
  when "1" then Taxon::IUCN_CRITICALLY_ENDANGERED
  when "2" then Taxon::IUCN_ENDANGERED
  when "3" then Taxon::IUCN_VULNERABLE
  when "4" then Taxon::IUCN_LEAST_CONCERN
  when "5" then Taxon::IUCN_LEAST_CONCERN
  when "N" then Taxon::IUCN_NOT_EVALUATED
  when "U" then Taxon::IUCN_DATA_DEFICIENT
  else Taxon::IUCN_LEAST_CONCERN
  end
end

def get_xml(url)
  puts "getting #{url}" if OPTS[:debug]
  Nokogiri::XML(open(url))
rescue Timeout::Error => e
  puts "  Timeout requesting #{url}, trying again..."
  begin
    Nokogiri::XML(open(url))
  rescue Timeout::Error => e
    puts "  Timeout requesting #{url}"
    nil
  end
rescue URI::InvalidURIError => e
  puts "  Bad URI (#{genus_url})"
  nil
rescue OpenURI::HTTPError => e
  puts "  Error getting #{url}: #{e}"
end

def natureServeStatus2iNatStatus(status_node, taxon, name, url, place = nil)
  iucn = rank2iucn(status_node.at('roundedRank/code').text)
  existing = ConservationStatus.where(:taxon_id => taxon, :authority => "NatureServe", :place_id => place).first

  if place && place.check_list && iucn != Taxon::IUCN_EXTINCT && !ListedTaxon.where(:taxon_id => taxon.id, :place_id => place.id).exists?
    # lt = ListedTaxon.new(:taxon => taxon, :place => place, :source => SOURCE)
    lt = place.check_list.add_taxon(taxon, :source => SOURCE)
    if lt.save
      puts "\tAdded #{lt}"
    else
      puts "\tFAILED to add #{lt}: #{lt.errors.full_messages.to_sentence}"
    end
  end

  if iucn < Taxon::IUCN_NEAR_THREATENED && existing.blank?
    puts "\tTaxon secure or data deficient, skipping conservation status..."
  else
    desc = [status_node.at('roundedRank/description').try(:text), status_node.at('reasons').try(:text)].compact.join('. ').strip
    puts "\tstatus: #{status_node.at('rank/code').text}" if OPTS[:debug]
    attrs = {
      :taxon => taxon,
      :place => place,
      :status => status_node.at('rank/code').text,
      :description => desc,
      :authority => "NatureServe",
      :iucn => iucn,
      :source => SOURCE,
      :url => url
    }
    if existing
      if existing.update_attributes(attrs)
        puts "\tUpdated #{existing} (#{name})"
      else
        puts "\tFAILED to update #{existing}: #{existing.errors.full_messages.to_sentence} (#{name})"
      end
    else
      cs = ConservationStatus.new(attrs)
      if cs.save
        puts "\tCreated #{cs} (#{name})"
      else
        puts "\tFAILED to create #{cs}: #{cs.errors.full_messages.to_sentence} (#{name})"
      end
    end
  end
end

def work_on_uid(uid, options = {})
  print uid
  doc = options[:doc]
  unless doc
    uid_url = "https://services.natureserve.org/idd/rest/ns/v1.1/globalSpecies/comprehensive?uid=#{uid}&NSAccessKeyId=#{KEY}"
    # doc = Nokogiri::XML(open(uid_url))
    doc = get_xml(uid_url)
  end
  unless doc
    puts
    puts "\tCouldn't get response from NatureServe for #{uid}, skipping..."
    return
  end
  if name = doc.at('scientificName/unformattedName').text
    puts " (#{name})"
  else
    puts
    puts "\tCouldn't parse name for #{uid}"
    return
  end

  url = doc.at('natureServeExplorerURI').text

  taxon = options[:taxon]
  taxon ||= Taxon.active.joins(:taxon_scheme_taxa).where("taxa.name = ? AND taxon_scheme_taxa.source_identifier = ?", name, uid).first
  taxon ||= Taxon.single_taxon_for_name(name)
  taxon ||= Taxon.active.find_by_name(name)
  if OPTS[:create_taxa] && name !~ /sp\.?\s+\d+/ && name !~ / spp/
    taxon ||= Taxon.new(
      :name => name, 
      :rank => Taxon::SPECIES, 
      :source => SOURCE,
      :source_url => url,
      :source_identifier => uid
    )
    unless OPTS[:debug]
      if taxon.save
        taxon.graft_silently
      end
      puts "\tAdded taxon: #{taxon}"
    end
  end
  if taxon && taxon.new_record? && !taxon.valid?
    puts "\tCouldn't create taxon for #{uid} (#{name}): #{taxon.errors.full_messages.to_sentence}"
    return
  elsif taxon.blank?
    puts "\tCouldn't find taxon for #{uid} (#{name})"
    return
  end
  if ( gs = doc.at( "globalStatus" ) ) && PLACE.blank?
    natureServeStatus2iNatStatus(gs, taxon, name, url)
  end

  doc.search("nationalStatus").each do |ns|
    puts "  #{ns[:nationName]} (#{ns[:nationCode]})"
    place = Place.where(:place_type => Place::PLACE_TYPE_CODES['country'], :code => ns[:nationCode]).first
    place ||= Place.where(:place_type => Place::PLACE_TYPE_CODES['country'], :name => ns[:nationName]).first
    unless place
      puts "    Couldn't find matching place. Skipping..."
      next
    end
    unless PLACE && place != PLACE
      natureServeStatus2iNatStatus(ns, taxon, name, url, place)
    end
    ns.search("subnationalStatus").each do |sns|
      puts "    #{sns[:subnationName]} (#{sns[:subnationCode]})"
      subplace = place.children.where(:code => sns[:subnationCode]).first
      subplace ||= place.children.where(:name => sns[:subnationName]).first
      next if PLACE && subplace != PLACE
      unless subplace
        puts "      Couldn't find matching place. Skipping..."
        next
      end
      natureServeStatus2iNatStatus(sns, taxon, name, url, subplace)
    end
  end
end

# CSV.foreach('stanford_nsx_uids_201207.csv') do |row|
#   work_on_uid(row[0])
# end
puts "OPTS.ancestor: #{OPTS.ancestor}"
scope = if OPTS.ancestor
  ancestor_name = OPTS.ancestor.humanize
  unless ancestor = Taxon.find_by_name( ancestor_name )
    puts "No ancestor taxon matching #{ancestor_name}"
    exit(0)
  end
  puts "ancestor: #{ancestor}"
  if ancestor.genus?
    Taxon.where(:id => ancestor.id)
  elsif ancestor.species?
    Taxon.where( "id = ? OR ancestry LIKE ?", ancestor, "#{ancestor.ancestry}/#{ancestor.id}/%")
  else
    ancestor.descendants.where(:rank => Taxon::GENUS)
  end
else
  Taxon.where(:rank => Taxon::GENUS)
end

scope = scope.where("taxa.id >= ?", OPTS.min_id) if OPTS.min_id
scope = scope.where("taxa.id <= ?", OPTS.max_id) if OPTS.max_id

scope.find_each do |taxon|
  print taxon.name.upcase
  taxon_url = "https://services.natureserve.org/idd/rest/ns/v1/globalSpecies/list/nameSearch?name=#{taxon.name}*&NSAccessKeyId=#{KEY}"
  unless doc = get_xml( taxon_url )
    puts "  Skipping..."
    next
  end
  uids = doc.search("speciesSearchResult").map{|n| n[:uid]}.uniq.compact
  puts " #{uids.size} matches"
  next if uids.blank?
  uids.in_groups_of(10) do |group|
    group.compact!
    uids_url = "https://services.natureserve.org/idd/rest/ns/v1.1/globalSpecies/comprehensive?uid=#{group.join(',')}&NSAccessKeyId=#{KEY}"
    unless doc = get_xml(uids_url)
      puts "  Skipping..."
      next
    end
    doc.search('globalSpecies').each do |n|
      work_on_uid(n[:uid], :doc => n)
    end
  end
end
puts
puts "Finished in #{Time.now - start} s"
