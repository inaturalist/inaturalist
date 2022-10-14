# this script is under construction. Currently it includes various methods for scraping external sources and some code for comparing with internal taxa covered by a taxon framework

require 'zip'

def get_external_taxa_powo_to_genus(other_taxon_frameworks)
  family_status_key = Hash.new
  content = Net::HTTP.get( URI( "https://storage.googleapis.com/powop-content/backbone/taxonomyFamilyGenus.zip" ) )
  Zip::File.open_buffer(content) do |zip|
    zip.each do |entry|
      if entry.name == "taxon.txt"
        data = entry.get_input_stream.read
        data.split("\n").each do |row|
          split_row = row.split("\t")
          family_status_key[split_row[0]] = split_row[4]
        end
      end
    end
  end

  external_taxa = []
  content = Net::HTTP.get( URI( "https://storage.googleapis.com/powop-content/backbone/taxonFamilyGenus.zip" ) )
  Zip::File.open_buffer(content) do |zip|
    zip.each do |entry|
      if entry.name == "taxon.txt"
        data = entry.get_input_stream.read
        data.split("\n").each do |row|
          split_row = row.split("\t")
          if family_status_key[split_row[0]] == "Accepted"
            external_taxa << {
              name: split_row[4],
              rank: "family",
              parent: {
                name: "Tracheophyta",
                rank: "phylum"
              },
              url: "http://www.plantsoftheworldonline.org/taxon/#{split_row[0]}"
            }
          end
        end
      end
    end
  end

  status_key = Hash.new
  content = Net::HTTP.get( URI( "https://storage.googleapis.com/powop-content/backbone/taxonomyWCS.zip" ) )
  Zip::File.open_buffer(content) do |zip|
    zip.each do |entry|
      if entry.name == "taxon.txt"
        data = entry.get_input_stream.read
        data.split("\n").each do |row|
          split_row = row.split("\t")
          status_key[split_row[0]] = split_row[6]
        end
      end
    end
  end

  content = Net::HTTP.get( URI( "https://storage.googleapis.com/powop-content/backbone/taxonWCS.zip" ) )
  Zip::File.open_buffer(content) do |zip|
    zip.each do |entry|
      if entry.name == "taxon.txt"
        data = entry.get_input_stream.read
        data.split("\n").each do |row|
          split_row = row.split("\t")
          if status_key[split_row[0]] == "Accepted"
            raw_rank = split_row[2]
            if raw_rank == "Genus"
              name = split_row[5]
              rank = "genus"
              parent = split_row[4]
              parent_rank = "family"
            elsif raw_rank == "Species"
              next
              #name = split_row[5] + " " + split_row[6]
              #rank = "species"
              #parent = split_row[5]
              #parent_rank = "genus"
            elsif ["var.","subsp.", "f."].include? raw_rank
              next
              #name = split_row[5] + " " + split_row[6] + " " + split_row[7]
              #if raw_rank == "var."
              #  rank = "variety"
              #elsif raw_rank == "subsp."
              #  rank = "subspecies"
              #else
              #  rank = "form"
              #end
              #parent = split_row[5] + " " + split_row[6]
              #parent_rank = "species"
            else
              next
            end
            external_taxa << {
              name: name,
              rank: rank,
              parent: {
                name: parent,
                rank: parent_rank
              },
              url: "http://www.plantsoftheworldonline.org/taxon/#{split_row[0]}"
            }
          end
        end
      end
    end
  end
  return external_taxa
end

def get_external_taxa_rd(other_taxon_frameworks)
  known_extinct = ["Chelonoidis phantasticus","Podarcis siculus sanctistephani","Cyclura cornuta onchiopsis","Aldabrachelys gigantea daudinii","Aldabrachelys abrupta","Aldabrachelys grandidieri","Chelonoidis abingdonii","Chelonoidis niger","Alinea luciae", "Bolyeria multocarinata", "Borikenophis sanctaecrucis", "Celestus occiduus", "Chioninia coctei", "Clelia errabunda", "Copeoglossum redondae", "Emoia nativitatis", "Erythrolamprus perfuscus", "Hoplodactylus delcourti", "Leiocephalus cuneus", "Leiocephalus eremitus", "Leiocephalus herminieri", "Leiolopisma mauritiana", "Oligosoma northlandi", "Phelsuma gigas", "Pholidoscelis cineraceus", "Pholidoscelis major", "Scelotes guentheri", "Tachygyia microlepis", "Tetradactylus eastwoodae", "Typhlops cariei"]
  puts "Downdloading data from Reptile Database..."
  external_taxa = []
  url = "http://reptile-database.reptarium.cz/interfaces/export/taxa.csv"
  CSV.new( Net::HTTP.get( URI( url ) ), :headers => :first_row, :col_sep => ";").each do |row|
    name = row['taxon_id'].split("_").join(" ")
    unless known_extinct.include? name
      rank = row['infraspecific_epithet'].nil? ? "species" : "subspecies"
      parent = (rank == "species") ? name.split(" ")[0] : name.split(" ")[0..1].join(" ")
      if rank == "species"
        url = "http://reptile-database.reptarium.cz/species?genus=#{name.split[0]}&species=#{name.split[1]}"
      else
        url = nil
      end
      if rank == "species"
        ancestry = [{name: row['family'], rank: "family"}, {name: parent, rank: "genus"}]
      else
        ancestry = [{name: row['family'], rank: "family"}, {name: row['genus'], rank: "genus"}, {name: parent, rank: "species"}]
      end
      external_taxa << {name: name, url: url, rank: rank, ancestry: ancestry}
    end
  end

  #add ancestors
  names_set = external_taxa.map{|a| a[:name]}.to_set
  new_names = []
  external_taxa.each do |row|
    base_ancestry = row[:ancestry]
    next if row[:rank] == "subspecies"
    next if row[:rank] == "family"
    row[:ancestry].each do |ancestor|
      ancestor_rank = ancestor[:rank]
      ancestor_name = ancestor[:name].capitalize
      if ancestor_rank == "family"
        unless (names_set.include? ancestor_name) || (new_names.include? ancestor_name)
          external_taxa << {name: ancestor_name, url: nil, rank: "family", ancestry: nil}
          new_names << ancestor_name
        end
      else
        unless (names_set.include? ancestor_name) || (new_names.include? ancestor_name)
          new_ancestry = base_ancestry[0..(base_ancestry.index(ancestor)-1)]
          new_url = nil
          external_taxa << {name: ancestor_name, url: new_url, rank: ancestor_rank, ancestry: new_ancestry}
          new_names << ancestor_name
        end
      end
    end
  end

  #exchange ancestry with parent
  root = "Reptilia"
  root_rank = "class"
  root_id = Taxon.where(name: root, rank: root_rank).first.id
  external_taxa.select{|row| !row[:ancestry].nil?}.map{|row| row[:parent] = row[:ancestry].last}
  external_taxa.select{|row| row[:ancestry].nil?}.map{|row| row[:parent] = {name: root, rank: root_rank}}
  external_taxa.each { |h| h.delete(:ancestry) }
  return external_taxa
end

def go_deeper_worms(ress, other_taxon_frameworks, tops)
  recs = []
  ress.each do |rec|
    next if other_taxon_frameworks.select{|a| a.taxon.name == rec[:name] && a.taxon.rank == rec[:rank]}.count > 0
    #next if ALT_CONCEPTS.select{|a| a[:name] == rec[:name] && a[:rank] == rec[:rank]}.count > 0
    puts rec.values.join(", ")
    puts rec[:id]
    url = "http://www.marinespecies.org/rest/AphiaChildrenByAphiaID/#{rec[:id]}?marine_only=false&offset=1"
    uri = URI( url )
    response = Net::HTTP.get( uri ); nil
    if response
      dat = JSON.parse( response ); nil
      resss = []
      dat.select{|row| 
        row["isExtinct"] != 1 && 
        (row["status"] == "accepted" || row["status"] == "temporary name") &&
        !(["Suborder", "Infraorder", "Parvorder", "Subsection", "Section", "Superfamily", "Family", "Subfamily", "Tribe", "Genus", "Subgenus", "Species", "Subspecies", "Form"].include? row["rank"])
      }.each do |row|
        if (row["scientificname"].include? "[unassigned]") || (row["scientificname"].include? "Incertae sedis") || (row["scientificname"].include? "incertae sedis")
          name = "Not assigned"
        else
          name = row["scientificname"]
        end
        resss << {
          id: row["AphiaID"],
          url: "http://www.marinespecies.org/aphia.php?p=taxdetails&id=#{row["AphiaID"]}",
          name: name, 
          rank: row["rank"].downcase, 
          parent_id: rec[:id]
        }
      end
      recs << resss
      puts rec[:rank]
      
      if tops.include? rec[:rank]
        recs << go_deeper_worms(resss, other_taxon_frameworks, tops)
      elsif na = resss.select{|a| a[:name] == "Not assigned"}.first
        recs << go_deeper_worms([na], other_taxon_frameworks, tops)
      end  
    end
  end
  return recs
end

def get_external_taxa_worms(other_taxon_frameworks)
  tops = Taxon::RANK_LEVELS.select{|k,v| v>=43}.keys #this will fetch through order
  url = "http://www.marinespecies.org/rest/AphiaRecordByAphiaID/2"
  uri = URI( url )
  response = Net::HTTP.get( uri ); nil
  row = JSON.parse( response ); nil
  res = [{name: row["scientificname"], id: row["AphiaID"], url: "http://www.marinespecies.org/aphia.php?p=taxdetails&id=#{row["AphiaID"]}", rank: row["rank"].downcase, parent_id: nil}]
  recs = []
  recs << res
  recs << go_deeper_worms(res, other_taxon_frameworks, tops)

  #roll up 'Not assigned'
  not_assigned = recs.flatten.select{|a| a[:name]=="Not assigned"}.map{|a| a[:id]}.to_set
  external_taxa = recs.flatten.select{|a| a[:name]!="Not assigned"}
  while external_taxa.select{|a| not_assigned.include? a[:parent_id]}.count > 0
    external_taxa.select{|a| not_assigned.include? a[:parent_id]}.map{|a| a[:parent_id] = recs.flatten.select{|b| b[:id]==a[:parent_id]}[0][:parent_id]}
  end

  #replace parent_id with parent
  root = "Animalia"
  root_rank = "kingdom"
  external_taxa.select{|row| row[:rank] != root_rank }.map{|row| row[:parent] = external_taxa.select{|item| item[:id] == row[:parent_id]}.map{|item| {name: item[:name], rank: item[:rank]} }.first}
  external_taxa.select{|row| row[:rank] == root_rank }.map{|item| item[:parent] = {name: nil, rank: nil}}
  external_taxa.each { |h| h.delete(:parent_id) }
  external_taxa.delete_at(0)
  return external_taxa
end

def go_deeper_col(resss, other_taxon_frameworks, tops)
  recs = []
  resss.each do |rec|
    next if other_taxon_frameworks.select{|a| a.taxon.name == rec[:name] && a.taxon.rank == rec[:rank]}.count > 0
    # this gives me the children of a node
    url = "http://www.catalogueoflife.org/annual-checklist/2018/browse/tree/fetch/taxa?id=#{rec[:id]}"
    uri = URI( url )
    response = Net::HTTP.get( uri ); nil
    dat = JSON.parse( response ); nil
    ress = dat["items"].
      select{|row| row["is_extinct"] == 0 && ([Taxon::RANK_LEVELS.select{|k,v| v<100 && v>=60}.keys,"not assigned"].flatten.include? row["rank"].downcase)}.
        map{|row| 
          {
            id: row["id"],
            url: "http://www.catalogueoflife.org/annual-checklist/2018/search/all/key/#{row["name"]}/fossil/0/match/1",
            name: row["name"], 
            rank: row["rank"].downcase, 
            parent_id: rec[:id]
          }
        }
    puts rec[:rank]
    recs << ress
    if tops.include? rec[:rank]
      recs << go_deeper_col(ress, other_taxon_frameworks, tops)
    elsif na = ress.select{|a| a[:name] == "Not assigned"}.first
      recs << go_deeper_col([na], other_taxon_frameworks, tops)
    end    
  end 
  return recs
end

def get_external_taxa_col(other_taxon_frameworks)
  #start at the root just do animals
  tops = Taxon::RANK_LEVELS.select{|k,v| v<100 && v>=100}.keys #this will fetch through order
  url = "http://www.catalogueoflife.org/annual-checklist/2018/browse/tree/fetch/taxa"
  uri = URI( url )
  response = Net::HTTP.get( uri ); nil
  dat = JSON.parse( response ); nil
  res = dat["items"].
    select{|row| row["is_extinct"] == 0}.
    map{|row| 
      {
        id: row["id"],
        url: "http://www.catalogueoflife.org/annual-checklist/2018/search/all/key/#{row["name"]}/fossil/0/match/1",
        name: row["name"],
        rank: "kingdom",
        parent_id: 0
      }
    }
  
  recs = [{id: 0, url: nil, name: "Life", rank: "stateofmatter", parent_id: nil}]
  root = "Life"
  root_rank = "stateofmatter"
  recs << res
  recs << go_deeper_col(res, other_taxon_frameworks, tops)
  
  #roll up 'Not assigned'
  not_assigned = recs.flatten.select{|a| a[:name]=="Not assigned"}.map{|a| a[:id]}.to_set
  external_taxa = recs.flatten.select{|a| a[:name]!="Not assigned"}
  while external_taxa.select{|a| not_assigned.include? a[:parent_id]}.count > 0
    external_taxa.select{|a| not_assigned.include? a[:parent_id]}.map{|a| a[:parent_id] = recs.flatten.select{|b| b[:id]==a[:parent_id]}[0][:parent_id]}
  end
  
  #replace parent_id with parent
  external_taxa.select{|row| row[:rank] != root }.map{|row| row[:parent] = external_taxa.select{|item| item[:id] == row[:parent_id]}.map{|item| {name: item[:name], rank: item[:rank]} }.first}
  external_taxa.select{|row| row[:rank] == root }.map{|item| item[:parent] = {name: nil, rank: nil}}
  external_taxa.each { |h| h.delete(:parent_id) }
  external_taxa.delete_at(0)
  return external_taxa
end

def get_internal_taxa_covered_by_taxon(taxon_framework)
  ancestry_string = taxon_framework.taxon.rank == "stateofmatter" ?
    "#{ taxon_framework.taxon_id }" : "#{ taxon_framework.taxon.ancestry }/#{ taxon_framework.taxon.id }"
  other_taxon_frameworks = TaxonFramework.joins(:taxon).
    where( "( taxa.ancestry LIKE ( '#{ ancestry_string }/%' ) OR taxa.ancestry LIKE ( '#{ ancestry_string }' ) )" ).
    where( "taxa.rank_level > #{ taxon_framework.rank_level } AND taxon_frameworks.rank_level IS NOT NULL" )

  other_taxon_frameworks_taxa = ( other_taxon_frameworks.count > 0 ) ?
    Taxon.where(id: other_taxon_frameworks.map(&:taxon_id)) : []

  internal_taxa = Taxon.select( "taxa.id, taxa.name, taxa.rank, taxa.rank_level, parent.id AS parent_id, parent.name AS parent_name, parent.rank AS parent_rank").
    where( "taxa.ancestry = ? OR taxa.ancestry LIKE ?", ancestry_string, "#{ancestry_string}/%" ).
    where( is_active: true ).
    joins( "JOIN taxa parent ON parent.id = (string_to_array(taxa.ancestry, '/')::int[])[array_upper(string_to_array(taxa.ancestry, '/')::int[],1)]" ).
    where( "taxa.rank_level >= ? ", taxon_framework.rank_level).
    where("( select count(*) from conservation_statuses ct where ct.taxon_id=taxa.id AND ct.iucn=70 AND ct.place_id IS NULL ) = 0")

  other_taxon_frameworks_taxa.each do |t|
    internal_taxa = internal_taxa.where("taxa.ancestry != ? AND taxa.ancestry NOT LIKE ?", "#{t.ancestry}/#{t.id}", "#{t.ancestry}/#{t.id}/%")
  end

  return internal_taxa
end

taxon_framework = TaxonFramework.includes("taxon").where(taxon_id: Taxon.where(name: "Life").first.id).first
if taxon_framework
  ancestry_string = taxon_framework.taxon.rank == "stateofmatter" ? "#{ taxon_framework.taxon_id }" : "%/#{ taxon_framework.taxon_id }"
  other_taxon_frameworks = TaxonFramework.includes( "taxon" ).joins( "INNER JOIN taxa ON taxon_frameworks.taxon_id = taxa.id" ).
    where( "( taxa.ancestry LIKE ( '#{ ancestry_string }/%' ) OR taxa.ancestry LIKE ( '#{ ancestry_string }' ) ) AND taxa.rank_level > #{ taxon_framework.rank_level } AND taxon_frameworks.rank_level IS NOT NULL" )

  #external_taxa = get_external_taxa_rd(other_taxon_frameworks)
  external_taxa = get_external_taxa_col(other_taxon_frameworks)
  #external_taxa = get_external_taxa_worms(other_taxon_frameworks)
  #external_taxa = get_external_taxa_powo_to_genus(other_taxon_frameworks)
  external_taxa_uids = external_taxa.map{|row| [row[:name],row[:rank],row[:parent][:name],row[:parent][:rank]].join("~")}

  internal_taxa = get_internal_taxa_covered_by_taxon(taxon_framework); nil
  internal_taxa_uids = internal_taxa.map{|row| [row["name"],row["rank"],row["parent_name"],row["parent_rank"]].join("~")}; nil
  
  discrepancies = []
  internal_taxa_in_discrepancies = discrepancies.map{|row| row[:internal_taxa].map{|item| item[:name]+"~"+item[:rank]}}.flatten
  external_taxa_in_discrepancies = discrepancies.map{|row| row[:external_taxa].map{|item| item[:name]+"~"+item[:rank]}}.flatten
  
  leftovers = external_taxa_in_discrepancies - external_taxa_uids
  if leftovers.count > 0
    puts "These are no longer in the external reference"
    leftovers.each do |name|
      puts "\t" + name
    end
  end

  added = (internal_taxa_in_discrepancies - external_taxa_in_discrepancies) & external_taxa_uids
  if added.count > 0
    puts "These have been added to the external reference"
    added.each do |name|
      puts "\t" + name
    end
  end

  leftovers = internal_taxa_in_discrepancies - internal_taxa_uids
  if leftovers.count > 0
    puts "These are no longer in iNat"
    leftovers.each do |name|
      puts "\t" + name
    end
  end

  added = (external_taxa_in_discrepancies - internal_taxa_in_discrepancies) & internal_taxa_uids
  if added.count > 0
    puts "These have been added to the iNat"
    added.each do |name|
      puts "\t" + name
    end
  end

  #not external
  swaps = (internal_taxa_uids.map{|a| a.split("~")[0..1].join("~")} - external_taxa_uids.map{|a| a.split("~")[0..1].join("~")}) - internal_taxa_in_discrepancies.map{|a| a.split("~")[0..1].join("~")}
  #not internal
  news = (external_taxa_uids.map{|a| a.split("~")[0..1].join("~")} - internal_taxa_uids.map{|a| a.split("~")[0..1].join("~")}) - external_taxa_in_discrepancies.map{|a| a.split("~")[0..1].join("~")}

  moves = []
  etus = external_taxa_uids.to_set; nil
  etus_np = external_taxa_uids.map{|a| a.split("~")[0..1].join("~")}.to_set; nil
  internal_taxa_uids_np = internal_taxa_uids.map{|a| a.split("~")[0..1].join("~")}; nil
  (0..(internal_taxa_uids.count-1)).each do |i|
    next if internal_taxa_in_discrepancies.include? internal_taxa_uids[i]
    if (etus_np.include? internal_taxa_uids_np[i]) && !(etus.include? internal_taxa_uids[i])
      name, rank, parent_name, parent_rank = internal_taxa_uids[i].split("~")
      lt = internal_taxa.select{ |a| a["name"] == name && a["rank"] == rank && a["parent_name"] == parent_name  && a["parent_rank"] == parent_rank }.first
      et = external_taxa.select{|a| a[:name] == name && a[:rank] == rank}.first
      ancestors = Taxon.find(lt["id"].to_i).ancestors.map{|a| [a.name,a.rank].join("~")}
      unless ancestors.include? et[:parent].values.join("~")
        moves << [lt,et]
      end
    end
  end

  puts "Swaps: #{swaps.count}"
  puts "News: #{news.count}"
  puts "Moves: #{moves.count}"
end