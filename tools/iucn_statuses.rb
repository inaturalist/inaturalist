require "rubygems"
require "optimist"

OPTS = Optimist::options do
    banner <<-EOS

This script updates and creates new global conservation statuses with authority IUCN Red List for a clade and generates a report summarizing
global conservation statuses compared to the current version of the IUCN Red List as well as any changes made.

Usage:

  bundle exec rails runner tools/iucn_statuses.rb --root-id 2 --try-to-repair --make-changes --show-not-internal --output-directory "/home/inaturalist/loarie"

where [options] are:
EOS
  opt :root_id, "the taxon_id of the root of the clade to be assessed", type: :int, short: "-r", default: 47792
  opt :make_changes, "create and update statuses", type: :boolean, short: "-m"
  opt :show_not_internal, "show IUCN names not represented in iNat", type: :boolean, short: "-n"
  opt :show_global_statuses_for_unassesed_species, "show non-IUCN global statuses on non-IUCN taxa?", type: :boolean, short: "-u"
  opt :stop_at_showing_internal, "If names not represented in iNat, stop after showing them", type: :boolean, short: "-p"
  opt :try_to_repair, "if valid taxon_name issues, repair them", type: :boolean, short: "-t"
  opt :output_directory, "directory to write report output to", type: :string, short: "-d", default: nil
  opt :api_key, "IUCN API key", :type => :string, :short => "-k"
end

def get_internal_taxa_covered_by_taxon( taxon )
  ancestry_string = "#{ taxon.ancestry }/#{ taxon.id }"
  internal_taxa = Taxon.
    where( "taxa.ancestry = ? OR taxa.ancestry LIKE ?", ancestry_string, "#{ ancestry_string }/%" ).
    where( is_active: true ).
    where( "( taxa.rank = 'species' OR taxa.rank = 'subspecies' OR taxa.rank = 'variety' )" )
  return internal_taxa
end

def get_status_and_url( taxonid, iucn_token )
  url = "http://apiv3.iucnredlist.org/api/v3/taxonredirect/#{ taxonid }?token=#{iucn_token }"
  uri = URI( url )
  iucn_url = Net::HTTP.get( uri )
  iucn_url = iucn_url.gsub( "Moved Temporarily. Redirecting to ","" )
  iucn_url = iucn_url.gsub( "Found. Redirecting to ","" )
  
  url = "http://apiv3.iucnredlist.org/api/v3/species/id/#{ taxonid }?token=#{ iucn_token }"
  uri = URI( url )
  response = Net::HTTP.get( uri ); nil
  dat = JSON.parse( response ); nil
  category = dat["result"][0]["category"]
  if ["LR/cd", "LR/nt"].include? category
    category = "NT"
  end
  if [ "LR/lc" ].include? category
    category = "LC"
  end
  return [ iucn_url, category ]
end

def get_iucn_data( iucn_token )
  proceed = true
  data = []
  i = 0
  while( proceed )
    url = "http://apiv3.iucnredlist.org/api/v3/species/page/#{ i }?token=#{ iucn_token }"
    uri = URI( url )
    response = Net::HTTP.get( uri ); nil
    dat = JSON.parse( response ); nil
    if dat["result"].count > 0
      data << dat["result"]
      i+=1
    else
      proceed = false
    end
  end
  data = data.flatten; nil
  return data
end

def update_status( cs, category, iucn_url, taxon )
  return true if cs.status == category && cs.url == iucn_url
  cs.status = category
  cs.iucn = IUCN_STATUS_CODES.invert[category]
  cs.url = iucn_url
  default_geoprivacy = ( ( ["NE", "LC", "DD"].include? category ) ? Observation::OPEN : Observation::OBSCURED )
  if taxon.observations_count == 0 && default_geoprivacy != cs.geoprivacy && !(cs.description.include? "/flags/")
    cs.geoprivacy = default_geoprivacy
  end
  if cs.save!
    puts "\t\tUpdated conservation status for #{ taxon.name }"
    return true
  else
    return false
  end
end

def create_status( category, taxon_id, iucn_url, geoprivacy, tname)
  cs = ConservationStatus.new(
    place_id: nil,
    authority: 'IUCN Red List',
    taxon_id: taxon_id,
    status: category,
    url: iucn_url,
    iucn: IUCN_STATUS_CODES.invert[category],
    geoprivacy: geoprivacy
  )
  if cs.save!
    puts "\t\tCreated conservation status for #{ tname }"
    return true
  else
    return false
  end
end

def get_taxa_without_single_valid_scientific_name_matching_taxon_dot_name( taxon_ids )
  Taxon.where( "is_active = true" ).
    where( "id IN (?)", taxon_ids ).
    where( "( select count( * ) from taxon_names tn where tn.taxon_id=taxa.id AND tn.lexicon = 'Scientific Names' AND is_valid = true AND lower( tn.name ) = lower( taxa.name ) ) != 1" )
end

def make_valid_scientific_names_unique( taxon )
  taxon_names = TaxonName.where("taxon_id = ? AND is_valid = true AND lower( name ) = ? AND lexicon = 'Scientific Names'", taxon.id, taxon.name.downcase )
  if taxon_names.count == 0
    if tn = TaxonName.where( "taxon_id = ? AND is_valid = false AND lower( name ) = ? AND lexicon = 'Scientific Names'", taxon.id, taxon.name.downcase ).first
   tn.is_valid = true
   tn.save!
    else
   tn = TaxonName.new(
     name: taxon.name,
     is_valid: true,
     lexicon: "Scientific Names",
     taxon_id: taxon.id
   )
   begin
     tn.save!
   rescue
     puts "error"
   end
    end
  elsif taxon_names.count > 1
    keeper = taxon_names.first
    taxon_names.where( "id != ?", keeper.id ).destroy_all
  end
end


def repair_non_unique_sci_names( taxa, taxon_ids )
  issues_count = taxa.count
  taxa.each do |taxon|
    make_valid_scientific_names_unique( taxon )
  end
  remaining_taxa = get_taxa_without_single_valid_scientific_name_matching_taxon_dot_name( taxon_ids )
  remaining_count = remaining_taxa.count
  puts "\t #{ issues_count - remaining_count } taxa with more than one or zero valid scientific taxon_name matching taxon.name repaired"
  return remaining_taxa
end

def not_one_valid_scientific_name_matching_taxon_name( taxon_ids, try_to_repair )
  taxa_with_issues = get_taxa_without_single_valid_scientific_name_matching_taxon_dot_name( taxon_ids )
  if taxa_with_issues.count == 0
    puts "\tAll taxa have exactly one valid scientific taxon_name matching taxon.name"
  else
    if try_to_repair
      taxa_with_issues = repair_non_unique_sci_names( taxa_with_issues, taxon_ids )
    end
    if taxa_with_issues.count > 0
      puts  "\t#{ taxa_with_issues.count } taxa with more than one or zero valid scientific taxon_name matching taxon.name:"
      taxa_with_issues.map{ |t| puts "\t#{ t.name }" }
    end
  end
end

def invalidate_sci_names_on_other_taxa( taxa, taxon_ids )
  issues_count = taxa.count
  taxa.each do |taxon|
    taxon_names = TaxonName.where( "taxon_id = ? AND lexicon = 'Scientific Names' AND is_valid = true AND lower( name ) != ?", taxon.id, taxon.name.downcase )
    taxon_names.update_all( "is_valid = false" )
  end
  remaining_taxa = get_taxa_with_valid_scientific_names_not_matching_taxon_dot_name( taxon_ids )
  remaining_count = remaining_taxa.count
  puts "\t #{ issues_count - remaining_count } taxa with valid scientific names not matching taxon.name made invalid"
  return remaining_taxa
end

def get_taxa_with_valid_scientific_names_not_matching_taxon_dot_name( taxon_ids )
  Taxon.where( "is_active = true" ).
   where( "id IN ( ? )", taxon_ids ).
   where( "( select count( * ) from taxon_names tn where tn.taxon_id = taxa.id AND lower( tn.name ) != lower( taxa.name ) AND tn.lexicon = 'Scientific Names' AND is_valid = true ) > 0" )
end

def valid_scientific_names_not_matching_taxon_name( taxon_ids, try_to_repair )
  taxa_with_issues = get_taxa_with_valid_scientific_names_not_matching_taxon_dot_name( taxon_ids )
  if taxa_with_issues.count == 0
    puts "\tNo taxa have valid scientific taxon_names not matching taxon.name"
  else
    if try_to_repair
      taxa_with_issues = invalidate_sci_names_on_other_taxa( taxa_with_issues, taxon_ids )
    end
    if taxa_with_issues.count > 0
      puts  "\t#{ taxa_with_issues.count } taxa with valid scientific taxon_names not matching taxon.name:"
      taxa_with_issues.map{ |t| puts "\t#{ t.name }" }
      exit( 0 )
    end
  end
end

IUCN_STATUS_CODES = {
  0 => "NE",
  5 => "DD",
  10 => "LC",
  20 => "NT",
  30 => "VU",
  40 => "EN",
  50 => "CR",
  60 => "EW",
  70 => "EX"
}

start = Time.now
puts OPTS
root_id = OPTS[:root_id]
make_changes =  OPTS[:make_changes]
show_not_internal = OPTS[:show_not_internal]
show_global_statuses_for_unassesed_species = OPTS[:show_global_statuses_for_unassesed_species]
stop_at_showing_internal = OPTS[:stop_at_showing_internal]
try_to_repair = OPTS[:try_to_repair]
output_directory = OPTS[:output_directory]
data_to_write = []

unless IUCN_TOKEN = OPTS.api_key
  puts "iucn token required"
  exit( 0 )
end

puts "Loading the IUCN RedList..."
iucn_data = get_iucn_data( IUCN_TOKEN )
allowed_ranks = ["kingdom", "phylum", "class", "order", "family"]

root = Taxon.find( root_id )
rank = root.rank
unless allowed_ranks.include? rank
  puts "must be in #{ allowed_ranks.join(", ") }"
  exit( 0 )
end
iucn_rank = "#{ rank }_name"
iucn_name = root.name.upcase
iucn_name = "NEMERTINA" if root.name == "Nemertea" && root.rank == "phylum"
puts "Working on #{ root.name }...."

puts "Getting internal taxa..."
ancestry_string = "#{ root.ancestry }/#{ root.id }"
internal_taxa = get_internal_taxa_covered_by_taxon( root )
internal_names = internal_taxa.map{ |t| t.name }
if internal_names.count == 0
  puts "\tNo internal taxa in that clade"
  exit( 0 )
else
  puts "\t#{ internal_names.count } internal taxa"  
end

puts "Getting external taxa..."
external_subset = iucn_data.select{ |t| t[iucn_rank] == iucn_name && t["population"].nil? }; nil
if external_subset.count == 0
  puts "\tNo iucn taxa in that clade"
  exit( 0 )
else
  puts "\t#{ external_subset.count } iucn taxa"
end
external_names = external_subset.map{ |t| t["scientific_name"].gsub( " ssp. "," " ).gsub( " subsp. ", " ").gsub( " cf. "," " ).gsub(" var. ", " ") }

puts "Make sure there aren't aren't any duplicates in the matching taxa..."
matches = ( internal_names & external_names )
external_dups = external_names.sort.chunk{ |e| e }.select { |e, chunk| chunk.size > 1 }.map( &:first )
internal_dups = internal_names.sort.chunk{ |e| e }.select { |e, chunk| chunk.size > 1 }.map( &:first )
ambiguous_dups = [external_dups,internal_dups].flatten & matches
if ambiguous_dups.count == 0 
  puts "\tNone of the matching taxa are duplicated"
else
  puts "\tThe following matching taxa are duplicated, please fix any errors or run this on a narrower branch"
  ambiguous_dups.map{ |t| puts "\t\t#{ t }" }
  exit( 0 )
end

puts "Looking for taxa with more than one or zero valid scientific taxon_name matching the taxon.name..."
not_one_valid_scientific_name_matching_taxon_name( internal_taxa.pluck( :id ), try_to_repair )

puts "Looking for taxa with valid scientific taxon_names not matching the taxon.name..."
valid_scientific_names_not_matching_taxon_name( internal_taxa.pluck( :id ), try_to_repair )

puts "Mapping one-to-ones..."
match_set = matches.to_set
not_external = ( internal_names - external_names )
not_internal = ( external_names - internal_names )
one_to_ones = []
already_matched = []
tns = TaxonName.select( "taxon_names.name AS taxon_name, taxa.name AS taxon_dot_name" ).joins( :taxon ).
  where( "taxon_names.lexicon = 'Scientific Names' AND taxon_names.is_valid = FALSE" ).
  where( "taxon_names.name IN ( ? ) AND taxa.is_active = TRUE", not_internal )
tns.each do |tn|
  if matches.include? tn.taxon_dot_name
    already_matched << { external: tn.taxon_name, match: tn.taxon_dot_name }
  else
    one_to_ones << { internal: tn.taxon_dot_name, external: tn.taxon_name }
  end
end

if already_matched.count > 0
  puts "#{ already_matched.count } external names already directly matched by some other external name:"
  puts "\tinternal <-> external"
  already_matched.sort_by{ |i| i[:match] }.each do |row|
    puts "\t#{ [row[:match],row[:external]].join( " <-> " ) }"
  end
  puts " "
end

# remove one-to-manys where neither IUCN taxa names exactly matches an iNat taxa name
multiple_indirects = []
one_to_manys = one_to_ones.map{ |a| a[:internal] }.group_by{ |e| e }.select { |k, v| v.size > 1 }.map( &:first )
if one_to_manys.count > 0
  puts "#{one_to_manys.count} external names attempting to indirectly match to the same internal taxon:"
  puts "\tinternal <-> external"
  one_to_ones.select{ |i| one_to_manys.include? i[:internal] }.sort_by{ |i| i[:internal] }.each do |row|
    puts "\t#{ [row[:internal],row[:external]].join( " <-> " ) }"
    multiple_indirects << row
  end
  one_to_ones = one_to_ones.select{ |a| !( one_to_manys.include? a[:internal] ) }
  puts " "
end

#tally portions
puts "Tallying proporitons..."
puts "\tmatches: #{ matches.count }"
puts "\tone to ones: #{ one_to_ones.count }"
puts "\tnot external: #{ ( not_external - one_to_ones.map{ |a| a[:internal] } ).count }"
puts "\tnot internal: #{ ( not_internal - one_to_ones.map{ |a| a[:external] } ).count }"
puts ""

#What are the IUCN (non-internal) names that aren't even represented as unique synonyms on iNat taxa 
puts "Counting external names not represented internally"
if show_not_internal
  not_internal = ( not_internal - one_to_ones.map{ |a| a[:external] } - already_matched.map{ |a| a[:external] } - multiple_indirects.map{ |a| a[:external] } )
  if not_internal.count == 0
    puts "\tNo external names not represented internally"
  else
    puts "\t#{ not_internal.count } external names not represented internally:"
    not_internal.each do |name|
      puts "\t\t#{ name }"
    end
  end
  exit( 0 ) if stop_at_showing_internal
end

puts "Calculating all matches..."
soft_match = [ matches, one_to_ones.map{ |a| a[ :internal ]  }].flatten.to_set
soft_match_taxon_ids = internal_taxa.select{ |a| soft_match.include? a.name }.pluck( :id )
if soft_match_taxon_ids.count == 0
  puts "\tNot taxa that can be matched"
  exit( 0 )
else
  puts "\t#{ soft_match_taxon_ids.count } taxa that can be matched"
end

puts "Ensuring only one IUCN global status..."
tids = ConservationStatus.joins( :taxon ).
  where( "taxa.id IN (?) AND taxa.is_active = true", soft_match_taxon_ids ).
  where( "conservation_statuses.place_id IS NULL AND conservation_statuses.authority = 'IUCN Red List'" ).
  pluck( "conservation_statuses.taxon_id" )
duplicate_iucn_statuses = tids.select{ |e| tids.count(e) > 1 }.uniq
if duplicate_iucn_statuses.count > 0
  puts "Taxa witht the following taxon_ids have more than one IUCN global status:"
  duplicate_iucn_statuses.each do |t|
    puts "\t\t#{ t }"
    cs = ConservationStatus.where(taxon_id: t, authority: "IUCN Red List", place_id: nil)
    keeper = cs.first
    ditchers = cs.where("id != ?", keeper.id)
    ditchers.destroy_all
  end
else
  puts "\tThere is no more than one IUCN status per taxon"
end

puts "Work through #{ soft_match_taxon_ids.count } taxa to update and create..."
created = []
to_create = []
to_update = []
external_subset.sort_by{ |i| i["scientific_name"] }.each do |row|
  name = row["scientific_name"].gsub( " ssp. "," " ).gsub( " subsp. ", " " ).gsub( " cf. "," " ).gsub( " var. ", " " )
  if mapped = one_to_ones.select{ |a| a[:external]==name }.first
    name = mapped[:internal]
  end
  next unless t = Taxon.where( "is_active = ? AND name = ? AND ( ancestry = ? OR ancestry LIKE ( ? ) )", true, name, ancestry_string, "#{ ancestry_string }/%" ).first
  puts "\tWorking on #{ row["scientific_name"] }..."
  begin
    iucn_url, category = get_status_and_url( row["taxonid"], IUCN_TOKEN )
  rescue
    iucn_url, category = get_status_and_url( row["taxonid"], IUCN_TOKEN )
  end
  if cs = ConservationStatus.where( place_id: nil, authority: 'IUCN Red List', taxon_id: t.id ).first
    if make_changes
      unless update_status( cs, category, iucn_url, t )
        puts "\t\tProblem updating conservation status for #{ t.name }"
      end
    else
      if cs.status != category
        to_update << { taxon_id: t.id, old_status: cs.status, new_status: category, obs_count: t.observations_count }
      end
    end
  else
    delayed_obscuring = false
    geoprivacy = ( ( ["NE", "LC", "DD"].include? category ) ? Observation::OPEN : Observation::OBSCURED )
    geoprivacy = Observation::OPEN if ( t.observations_count > 100 && geoprivacy == Observation::OBSCURED )
    if make_changes
      if create_status( category, t.id, iucn_url, geoprivacy, t.name )
        created << { taxon_id: t.id, status: category, geoprivacy: geoprivacy, obs_count: t.observations_count }
      else
        puts "\t\tProblem creating conservation status for #{ t.name }"
      end
    else
      to_create << { taxon_id: t.id, status: category, geoprivacy: geoprivacy, obs_count: t.observations_count }
    end
  end
end

puts "Calculating deviations from default positions..."
matrix = ConservationStatus.joins( :taxon ).
  where( "taxa.id IN ( ? ) AND taxa.is_active = true AND conservation_statuses.place_id IS NULL AND conservation_statuses.authority = 'IUCN Red List'", soft_match_taxon_ids ).
  map{ |a| 
    {
      taxon_id: a.taxon_id, 
      geoprivacy: a.geoprivacy, 
      status: ( ( ["NE", "LC", "DD"].include? a.status ) ? "secure" : "threatened" ), 
      description: a.description
    }
  }
matrix.each do |a|
  t = Taxon.find( a[:taxon_id] )
  a[:observations_count] = t.observations_count
  a[:name] = t.name
  a[:flag] = ( !a[:description].nil? && ( a[:description].include? "/flags/" ) ) ? a[:description] : nil
end

mat = {
  open_and_secure: matrix.select{ |a| ( a[:geoprivacy]==Observation::OPEN || a[:geoprivacy].nil? ) && a[:status]=="secure" }.count,
  obscured_and_threatened: matrix.select{ |a| a[:geoprivacy]!=Observation::OPEN && !a[:geoprivacy].nil? && a[:status]=="threatened" }.count,
  obscured_and_secure: matrix.select{ |a| a[:geoprivacy]!=Observation::OPEN && !a[:geoprivacy].nil? && a[:status]=="secure" }.count,
  open_and_threatened: matrix.select{ |a| ( a[:geoprivacy]==Observation::OPEN || a[:geoprivacy].nil? ) && a[:status]=="threatened" }.count
}
puts "\tOpen and secure: #{ mat[:open_and_secure] }"
puts "\tObscured and threatened: #{ mat[:obscured_and_threatened] }"
puts "\tObscured and secure: #{ mat[:obscured_and_secure] }"
puts "\tOpen and threatened: #{ mat[:open_and_threatened] }"

if mat[:obscured_and_secure] > 0
  puts "\tThe following are obscured and secure..."
  puts "\t\turl, name, obs_count, flag"
  matrix.select{ |a| a[:geoprivacy] != Observation::OPEN && !a[:geoprivacy].nil? && a[:status]=="secure" }.
    sort_by{ |a| a[:observations_count] }.reverse.each do |row|
    puts "\t\t#{ ["https://www.inaturalist.org/taxa/#{ row[:taxon_id] }", row[:name], row[:observations_count], row[:flag]].join( ", " ) }"
    data_to_write << ["obscured_and_secure", "https://www.inaturalist.org/taxa/#{ row[:taxon_id] }", row[:name], row[:observations_count], row[:flag]]
  end
end
if mat[:open_and_threatened] > 0
  puts "\tThe following are open and threatened..."
  puts "\t\turl, name, obs_count, flag"
  matrix.select{ |a| ( a[:geoprivacy]==Observation::OPEN || a[:geoprivacy].nil? ) && a[:status]=="threatened" }.
    sort_by{|a| a[:observations_count]}.reverse.each do |row|
    puts "\t\t#{ ["https://www.inaturalist.org/taxa/#{ row[:taxon_id] }", row[:name], row[:observations_count], row[:flag]].join( ", " ) }"
    data_to_write << ["open_and_threatened", "https://www.inaturalist.org/taxa/#{ row[:taxon_id] }", row[:name], row[:observations_count], row[:flag]]
  end
end
  
if make_changes && created.select{ |a| a[:geoprivacy]== Observation::OBSCURED &&  a[:obs_count]>0 }.count > 0
  puts "The following obscuring statuses were created..."
  puts "\turl, name, status, geoprivacy, obs_count"
  created.select{ |a| a[:geoprivacy]== Observation::OBSCURED &&  a[:obs_count]>0 }.sort_by{ |a| a[:obs_count] }.reverse.each do |row|
    t = Taxon.find( row[:taxon_id] )
    puts "\t#{ ["https://www.inaturalist.org/taxa/#{ row[:taxon_id] }", t.name, row[:status], row[:obs_count]].join( ", " ) }"
    data_to_write << ["new_obscuring_statuses", "https://www.inaturalist.org/taxa/#{ row[:taxon_id] }", t.name, row[:obs_count], nil]
  end
else
  if to_create.select{|a| a[:geoprivacy]== Observation::OBSCURED &&  a[:obs_count]>0}.count > 0
    puts "The following obscuring statuses would be created..."
    puts "\ttaxon, status, geoprivacy, obs_count"
    to_create.select{|a| a[:geoprivacy]== Observation::OBSCURED &&  a[:obs_count]>0}.sort_by{|a| a[:obs_count]}.reverse.each do |row|
      puts "\t#{[Taxon.find(row[:taxon_id]).name, row[:status], row[:geoprivacy], row[:obs_count]].join(", ")}"
    end
  end
  if to_update.count > 0
    puts "The following statuses would be updated..."
    puts "\ttaxon, old status, new status, obs_count"
    to_update.sort_by{ |a| a[:obs_count] }.reverse.each do |row|
      puts "\t#{ [Taxon.find( row[:taxon_id] ).name, row[:old_status], row[:new_status], row[:obs_count]].join( ", " ) }"
    end
  end
end

puts "Looking at other global statuses..."
other_global_statuses = []
tids = ConservationStatus.joins( :taxon ).where( "taxa.id IN (?) AND taxa.is_active = true AND conservation_statuses.place_id IS NULL", soft_match_taxon_ids ).
  pluck( "conservation_statuses.taxon_id" )
other_stauses = tids.select{ |e| tids.count( e ) > 1 }.uniq
if other_stauses.count > 0
  puts "\t#{ other_stauses.count } duplicate global statuses"
  other_stauses.each do |t|
    tax = Taxon.find( t )
    next unless iucn_one = ConservationStatus.joins( :taxon ).where( "conservation_statuses.authority = 'IUCN Red List' AND conservation_statuses.place_id IS NULL" ).
      where( "taxa.id = ? AND taxa.is_active = true", t ).first
    iucn_geoprivacy = iucn_one.geoprivacy
    iucn_geoprivacy = Observation::OPEN if iucn_geoprivacy.nil?
    ConservationStatus.joins( :taxon ).
      where( "conservation_statuses.authority != 'IUCN Red List' AND taxa.id = ? AND taxa.is_active = true AND conservation_statuses.place_id IS NULL", t ).each do |cs|
      geoprivacy = cs.geoprivacy
      geoprivacy = Observation::OPEN if geoprivacy.nil?
      if ( iucn_geoprivacy == geoprivacy ) || ( geoprivacy == Observation::OPEN )
        #ok to delete global non-obscuring statuses
        if make_changes
          puts "\t\t#{ ["https://www.inaturalist.org/taxa/#{ t }", tax.name, cs.status, geoprivacy, cs.authority, iucn_one.status, iucn_geoprivacy].join( ", " ) }\t\tdestroyed"      
          cs.skip_update_observation_geoprivacies = true
          cs.destroy
        else
          puts "\t\t#{ ["https://www.inaturalist.org/taxa/#{ t }", tax.name, cs.status, geoprivacy, cs.authority, iucn_one.status, iucn_geoprivacy].join( ", " ) }"      
        end
      else
        #rather log obscuring ones
        puts "\t\t#{ ["https://www.inaturalist.org/taxa/#{ t }", tax.name, cs.status, geoprivacy, cs.authority, iucn_one.status, iucn_geoprivacy].join( ", " ) }"
        data_to_write << ["duplicate_global_statuses", "https://www.inaturalist.org/taxa/#{ t }", tax.name, tax.observations_count, nil]
      end
    end
  end
else
  puts "\tThere are no other global statuses"
end

puts "Looking for IUCN statuses on active taxa that shouldn't have them..."
all_statuses = ConservationStatus.select( "taxon_id, taxa.name, authority, geoprivacy, status, taxa.observations_count" ).joins( :taxon ).
  where( "taxa.id IN (?) AND taxa.is_active = true AND conservation_statuses.place_id IS NULL", internal_taxa.pluck( :id ) )
all_statuses.select{ |i| i.geoprivacy.nil? }.map{ |i| i.geoprivacy = Observation::OPEN }
one_to_one_set = one_to_ones.map{ |a| a[:internal] }.to_set
orphaned_open_iucn_statuses = all_statuses.select{ |a| !( match_set.include? a[:name] ) && !( one_to_one_set.include? a[:name] ) && a[:authority]=="IUCN Red List" && a[:geoprivacy]==Observation::OPEN }
if orphaned_open_iucn_statuses.count > 0
  puts "\t#{ orphaned_open_iucn_statuses.count } orphaned open iucn statuses (destroying):"
  "taxon_id, former authority, status, geoprivacy, name, observations_count"
  orphaned_open_iucn_statuses.sort_by{ |i| i.observations_count }.reverse.each do |row|
    ct = ConservationStatus.where( taxon_id: row[:taxon_id], authority: "IUCN Red List", place_id: nil ).first
    if ct.destroy
      puts "\t\t#{ row.attributes.values[1..-1].join(", ") }\t\tdestroyed"
    end
  end
else
  puts "\tThere are no orphaned open statuses"
end

orphaned_iucn_statuses = all_statuses.select{ |a| !( match_set.include? a[:name] ) && !( one_to_one_set.include? a[:name] ) && a[:authority]=="IUCN Red List" && a[:geoprivacy]!=Observation::OPEN }
if orphaned_iucn_statuses.count > 0
  puts "\t#{ orphaned_iucn_statuses.count } orphaned obscuring IUCN Red List statuses. Destroying if no current identifications, otherwise changing authority to nil:"
  "taxon_id, former authority, status, geoprivacy, name, observations_count"
  orphaned_iucn_statuses.sort_by{ |i| [i.geoprivacy, i.observations_count] }.reverse.each do |row|
    next unless ct = ConservationStatus.where(taxon_id: row[:taxon_id], authority: "IUCN Red List", place_id: nil).first
    if row[:observations_count] == 0 && INatAPIService.identifications( { taxon_id: row[:taxon_id], current: true } ).total_results == 0
      if ct.destroy
        puts "\t\t#{ row.attributes.values[1..-1].join(", ") }\t\tdestroyed"
      end
    else
      ct.authority = nil
      if ct.save!
        puts "\t\t#{ row.attributes.values[1..-1].join(", ") }"
        data_to_write << ["vestigial_obscuring_statuses", "https://www.inaturalist.org/taxa/#{ ct.taxon_id }", ct.taxon.name, ct.taxon.observations_count, nil]
      end
    end
  end
else
  puts "\tThere are no orphaned obscuring statuses"
end

puts "Assessing IUCN statuses on coarser ranks than species within the clade..."
statuses = ConservationStatus.select( "conservation_statuses.id, taxa.name, taxa.observations_count, geoprivacy, status" ).joins( :taxon ).
  where( "taxa.ancestry = ? OR taxa.ancestry LIKE ?", ancestry_string, "#{ ancestry_string }/%" ).
  where( "taxa.rank_level > 10 AND taxa.is_active = true" ).
  where( "conservation_statuses.place_id IS NULL AND conservation_statuses.authority = 'IUCN Red List'" )
unless statuses.empty?
  puts "\t#{ statuses.map{|i| i.id}.count } taxa with IUCN coarse statuses, setting authority to nil or safely destroying..."
  puts "\ttaxon_id, status, geoprivacy, name, observations_count"
  statuses.select{ |i| i.geoprivacy.nil? }.map{ |i| i.geoprivacy = Observation::OPEN }
  statuses.sort_by{ |i| [i.geoprivacy, i.observations_count] }.reverse.each do |i|
    next unless status = ConservationStatus.where( id: i.id ).first
    if i.status == "EX" || i.geoprivacy == Observation::OBSCURED || i.geoprivacy == Observation::PRIVATE
      status.authority = nil
      status.skip_update_observation_geoprivacies = true
      status.save!
      puts "\t#{ i.attributes.to_h.values.join( ", " ) }"
    else
      status.skip_update_observation_geoprivacies = true
      status.destroy
      puts "\t#{ i.attributes.to_h.values.join( ", " ) }\t\tdestroyed"
    end
  end
else
  puts "\tNo statuses on coarser ranks than species within the clade"
end


if show_global_statuses_for_unassesed_species
  puts "Assessing global statuses for unassessed species..."
  all_statuses = ConservationStatus.select( "taxon_id, taxa.name, authority, geoprivacy, status, taxa.observations_count" ).joins( :taxon ).
    where( "taxa.id IN ( ? ) AND taxa.is_active = true AND conservation_statuses.place_id IS NULL", internal_taxa.pluck( :id ) )
  all_statuses.select{ |i| i.geoprivacy.nil? }.map{ |i| i.geoprivacy = Observation::OPEN }
  statuses_on_unassessed_species = all_statuses.select{ |a| !( match_set.include? a[:name] ) && !( one_to_one_set.include? a[:name] ) && a[:authority]!="IUCN Red List" }
  if statuses_on_unassessed_species.count > 0
    puts "\t#{ statuses_on_unassessed_species.count } global statuses on unassessed species..."
    statuses_on_unassessed_species.sort_by{ |i| [i.geoprivacy, i.observations_count] }.reverse.each do |row|
      puts "\t\t#{ row.attributes.values[1..-1].join(", ") }"
    end
  else
    puts "\tThere are no global statuses on unassessed species"
  end
end

unless output_directory.nil?
  puts "Writing data out to a file..."
  CSV.open( "#{ output_directory }/iucn_statuses_output_#{ root.name }_#{ Time.now.to_i }.csv", "w" ) do |csv|
    csv << ["category", "ur", "name", "observations_count", "flag"]
    data_to_write.each do |row|
      csv << row
    end
  end
end

puts
puts "Finished in #{ Time.now - start } s"
