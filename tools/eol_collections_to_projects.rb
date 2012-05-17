require 'rubygems'
require 'trollop'
require 'erb'

opts = Trollop::options do
    banner <<-EOS
This script is meant to keep the EOL projects on iNaturalist in sync with the
EOL collections in an EOL collection (yes, EOL has collections of collections)

Usage:
  script/runner tools/eol_collections_to_projects.rb <EOL collection url>

The script:
   1) makes projects for collections if they don't already exist but doesn't
     automatically add the icon, descripton, terms, or custom header - that
     would be nice
   2) adds listed_taxa to the list for the project for taxa in the EOL 
      collection
   3) removes any listed_taxa on the list for the project for taxa that 
      aren't on the EOL collection 
   4) records the names of taxa in the EOL collection that aren't represented 
      by any iNat taxon_names (these taxa or taxon_names will be manually
      added)

Improvements:
  How would I automatically create the project_icon from the EOL logo_url?
  More elegant way for stripping author of EOL Sci Name?

Options:
EOS
  # opt :defunct, "Path to archive", :type => :string, :short => "-d"
  opt :debug, "Print debug statements", :type => :boolean, :short => "-d"
  opt :user, "Username or ID of the EOL user on iNat that owns these projects", :type => :string, :short => "-u", :default => "eol"
  opt :logo, "URL of logo to use for the project icons", :type => :string, :short => "-l"
  opt :header, "Path to an ERB template file for a custom header. Bound variables should be project, collection_title, collection_url, and collection_image_url", :type => :string, :short => "-h"
  opt :css, "Path to an CSS file.", :type => :string, :short => "-c"
  opt :test, "Don't actually touch the db", :short => "-t", :type => :boolean
end

unless eol_collection_url = ARGV[0]
  puts "You must specify the URL of an EOL collection of EOL collections"
  exit(0)
end

the_user = User.find_by_login(opts[:user])
the_user ||= User.find_by_id(opts[:user].to_i)
unless the_user
  puts "There is no iNat user with a login or ID matching '#{opts[:user]}'.  You must specify a user to own these projects."
  exit(0)
end

#Get the Collections in the iNaturalist Collection from EOL
unless response = Net::HTTP.get_response(URI.parse(eol_collection_url))
  puts "couldn't access iNat Collection on EOL"
  break
end
doc = Nokogiri::XML(response.body)
eol_collection_ids = doc.xpath('//object_id[../object_type/text() = "Collection"]').map(&:text)
eol_collection_ids.each do |eol_collection_id|
  # sleep(5)
  taxa_unchanged = [] 
  taxa_removed = []         #in the project_list as a listed_taxa but no longer in the eol collection
  taxa_added = []    #in the eol collection so added to the the project_list as a listed_taxa
  taxa_missing = []  #in the eol collection but not added because it doesn't exist as a taxon in iNat (make manually)
  begin
    #Get the collection
    url = "http://eol.org/api/collections/1.0/#{eol_collection_id}/?per_page=1000"
    puts url
    unless response = Net::HTTP.get_response(URI.parse(url))
      puts "\tcouldn't access Collection #{eol_collection_id} on EOL"
      next
    end
    col = Nokogiri::XML(response.body)
  rescue Timeout::Error => e
    sleep(5)
    begin
      #Get the collection
      unless response = Net::HTTP.get_response(URI.parse(url))
        puts "\tcouldn't access Collection #{eol_collection_id} on EOL"
        next
      end
      col = Nokogiri::XML(response.body)
    rescue Timeout::Error => e
      puts "\t#{e.message}"
      break
    end
  end
  
  begin
    collection_title = col.xpath('//name').first.text
    project_name = "#{collection_title} EOL Collection"
  rescue => e
    puts "\t Woah, couldn't find a name! Skipping... error: #{e}"
    next
  end
  collection_image_url = col.xpath('//logo_url').first.try(:text)
  logo_url = opts[:logo] || collection_image_url
  collection_url = "http://eol.org/collections/#{eol_collection_id}"
  
  #Make a new project for the collection if it doesn't exist
  puts "\tChecking whether iNat project '#{project_name}' exists...."
  project = Project.first(:conditions => { :source_url => collection_url })
  project ||= Project.first(:conditions => { :title => project_name })
  if project
    project.title = project_name
    project.source_url = collection_url if project.source_url.blank?
    project.description = col.at('description').try(:text)
    project.save
  else
    project = Project.new(
      :user_id => the_user.id, 
      :title => project_name,
      :source_url => "http://eol.org/collections/#{eol_collection_id}",
      :description => col.at('description').try(:text),
      :project_type => "contest")
    project.project_observation_rules.build(:operator => "on_list?")
    if logo_url
      io = open(URI.parse(logo_url))
      project.icon = (io.base_uri.path.split('/').last.blank? ? nil : io)
    end
    unless opts[:test]
      if project.save
        if opts[:header] || opts[:css]
          cp = project.build_custom_project
          if opts[:header] && tpl = (open(opts[:header]).read rescue nil)
            cp.head = ERB.new(tpl).result(binding)
          end
          if opts[:css]
            cp.css = open(opts[:css]).read rescue nil
          end
          cp.save
        end
      else
        puts "\t\t Failed to create project: #{project.errors.full_messages.to_sentence}"
      end
    end
    puts "\t\t Created iNat project '#{project_name}'"
  end
  
  #Find the project list and loop through the listed_taxa taxon_ids
  #so we can later see if any of these listed_taxa aren't on the collection anymore
  #and must be removed
  the_list = project.project_list
  listed_taxa_taxon_ids = the_list.listed_taxa.map{|lt| lt.taxon_id}
  
  collection_item_dwc_names = []
  
  col.xpath('//collection_items/item[object_type/text() = "TaxonConcept"]').each do |node|
    list_item = TaxonName.strip_author(node.at('name').text)
    collection_item_dwc_names << list_item
    annotation = node.at('annotation').try(:text)
    puts "\t name: #{list_item}"
    
    #Check to see if the list_item is a taxon_name associated with a taxon_id that already has a listed_taxon
    existing = the_list.listed_taxa.first(:include => {:taxon => :taxon_names}, :conditions => [
      "taxon_names.lexicon = ? AND taxon_names.name = ? AND listed_taxa.taxon_id IN (?)",
      TaxonName::SCIENTIFIC_NAMES,
      list_item.strip,
      listed_taxa_taxon_ids
    ])
    if existing
      puts "\t\t#{list_item} already on #{the_list}, updating..."
      existing.update_attributes(:description => annotation)
      listed_taxa_taxon_ids.delete(existing.taxon_id)
    else
      #find the taxon to make a listed taxon
      taxon = Taxon.single_taxon_for_name(list_item)
      taxon ||= Taxon.find_by_name(list_item.strip)
      taxon = nil if taxon && taxon.taxon_names.detect{|tn| tn.name == list_item}.blank?
      unless taxon
        external_names = Ratatosk.find(list_item)
        if match = external_names.detect{|en| en.name == list_item}
          match.save unless opts[:test]
          taxon = match.taxon
          if taxon.valid? && !taxon.new_record?
            puts "\t\tImported new taxon: #{taxon}"
            taxon.send_later(:graft) unless opts[:test]
          else
            puts "\t\tFailed to import #{taxon}: #{taxon.errors.full_messages.to_sentence}"
            taxon = nil
          end
        end
      end
      
      unless taxon
        rank = case list_item.split.size
        when 1 then "genus"
        when 2 then "species"
        else "subspecies"
        end
        taxon = Taxon.new(:name => list_item, :rank => rank)
        taxon.save unless opts[:test]
        puts "\t\tCreated new taxon: #{taxon}"
        taxon.send_later(:graft) unless opts[:test]
      end
      
      lt = ListedTaxon.new(:taxon_id => taxon.id, :list_id => the_list.id, :manually_added => true)
      lt.save unless opts[:test]
      #Record the taxon we just created a listed_taxon for under 'taxa_added'
      listed_taxa_taxon_ids.reject!{ |taxon_id| taxon_id == taxon.id }
      if lt.valid?
        puts "\t\tCreated #{lt} for #{list_item}"
        taxa_added << taxon.name
      else
        puts "\t\tFailed to create #{lt} for #{list_item}: #{lt.errors.full_messages.to_sentence}"
      end
    end
  end
    
  # Anything left on listed_taxa_taxon_ids doesn't exist on the EOL 
  # collection so the iNat listed_taxon will be destroyed IFF there's a rule 
  # specifying that obs must be on the list
  if project.project_observation_rules.exists?(:operator => "on_list?")
    listed_taxa_taxon_ids.each do |lt_taxon_id|
      thelt = the_list.listed_taxa.first(:conditions => { :taxon_id => lt_taxon_id } )
      thelt.destroy unless opts[:test]
      # Record the taxon we just destroyed the listed_taxon for under 'taxa_removed'
      taxa_removed << Taxon.find_by_id(lt_taxon_id).name
      puts "\tRemoved #{thelt} with taxon_id #{lt_taxon_id} which is no longer in the collection"
    end
  end
  
  # Print out the statistics for the collection: unchanged, added, removed, missing:
  puts "\tthe EOL collection has #{collection_item_dwc_names.count} items and the iNat project_list has #{the_list.listed_taxa.count} listed_taxa"

  if taxa_added.count > 0
    puts "\tthe added taxa are:"
    taxa_added.each do |t_a|
      puts "\t\t#{t_a}"
    end
  end
  if taxa_removed.count > 0
    puts "\tthe removed taxa are:"
    taxa_removed.each do |t_r|
      puts "\t\t#{t_r}"
    end
  end
  if taxa_missing.count > 0
    puts "\tthe missing taxa are:"
    taxa_missing.each do |t_m|
      puts "\t\t#{t_m}"
    end
  end
  puts
end

Project.all(:conditions => "source_url LIKE 'http://eol.org/collections%'").each do |p|
  unless p.source_url =~ /collections\/(#{eol_collection_ids.join('|')})$/
    p.destroy unless opts[:test]
    puts "Destroyed #{p}, no longer an EOL iNat collection"
  end
end
