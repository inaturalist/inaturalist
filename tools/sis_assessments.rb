require 'rubygems'
require 'trollop'

opts = Trollop::options do
    banner <<-EOS
Import / update SIS assessments.

Usage:

  rails runner tools/sis_assessments.rb [OPTIONS]

where [options] are:
EOS
  opt :debug, "Print debug statements", :type => :boolean, :short => "-d"
  opt :sis_username, "SIS username", :type => :string, :short => "-u"
  opt :sis_password, "SIS password", :type => :string, :short => "-p"
  opt :working_setid, "working set id", :type => :integer, :short => "-w"
  opt :project_id, "project id", :type => :string, :short => "-r"
end

start = Time.now

OPTS = opts

unless OPTS.sis_username
  puts "You need to specify a SIS username"
  exit(0)
end

unless OPTS.sis_password
  puts "You need to specify a SIS password"
  exit(0)
end

unless OPTS.working_setid
  puts "You need to specify a working set id"
  exit(0)
end

unless OPTS.project_id
  puts "You need to specify a project id"
  exit(0)
end

unless project = Project.find(OPTS.project_id)
  puts "Can't find the project"
  exit(0)
end

def get_auth_response(username, password)
  postData = Net::HTTP.post_form(URI.parse('http://api-dev.iucnsis.org/login'),{'username'=>username,'password'=>password})
rescue Timeout::Error => e
  puts "  Timeout, trying again..."
  begin
    postData = Net::HTTP.post_form(URI.parse('http://api-dev.iucnsis.org/login'),{'username'=>username,'password'=>password})
  rescue Timeout::Error => e
    puts "  Timeout"
    nil
  end
rescue URI::InvalidURIError => e
  puts "  Bad URI"
  nil
end

def parse_auth_response(auth_response)
  auth_token = JSON.parse auth_response.body
  auth_token['auth_token']
end

def get_json(url)
  response = Net::HTTP.get_response(URI.parse(url))
  json = JSON.parse response.body
rescue Timeout::Error => e
  puts "  Timeout, trying again..."
  begin
    response = Net::HTTP.get_response(URI.parse(url))
    json = JSON.parse response.body
  rescue Timeout::Error => e
    puts "  Timeout"
    nil
  end
rescue URI::InvalidURIError => e
  puts "  Bad URI"
  nil
end

def workingset_exists?(auth_token, working_setid)
  working_sets = get_json("http://api-dev.iucnsis.org/workingsets?key=#{auth_token}")
  if working_sets['working_sets']
    working_sets['working_sets'].each do |ws|
      if ws['working_setid'] == working_setid
        return true
      end
    end
  end
  false
end

def get_workingset_species(auth_token, working_setid)
  species = get_json("http://api-dev.iucnsis.org/workingsets/#{working_setid}/species?key=#{auth_token}")
  species["species"]
end

def get_most_recent_assessment_id(auth_token, iucn_id)
  assessments_json = get_json("http://api-dev.iucnsis.org/assessments/#{iucn_id}?key=#{auth_token}")
  assessments = assessments_json["assessments"]
  if assessments
    highest_assessment_id = 0
    assessments.each do |as|
      if as['id'] >  highest_assessment_id
        highest_assessment_id = as['id']
      end
    end
    if highest_assessment_id == 0
      return nil
    end
    highest_assessment_id
  else
    return nil
  end
end

def get_assessment(auth_token, assessment_id)
  details = get_json("http://api-dev.iucnsis.org/assessments/#{assessment_id}/details?key=#{auth_token}")
  details["details"]
end

unless auth_response = get_auth_response(OPTS.sis_username, OPTS.sis_password)
  puts "Can't login to SIS with specified username and password"
  exit(0)
end

unless auth_token = parse_auth_response(auth_response)
  puts "Can't get the auth token"
  exit(0)
end

unless workingset_exists?(auth_token, OPTS.working_setid)
  puts "Can't find workingset on SIS"
  exit(0)
end

if source = Source.find_by_title("IUCN Red List of Threatened Species. Version 2012.2")
  SOURCE = source
else
  SOURCE = Source.create(
    :title => "IUCN Red List of Threatened Species. Version 2012.2",
    :in_text => "IUCN 2012.2",
    :citation => "IUCN 2012. IUCN Red List of Threatened Species. Version 2012.2. <www.iucnredlist.org>. Downloaded on 13 November 2012.",
    :url => "http://www.iucnredlist.org/"
  )
end

if source = Source.find_by_title("Draft IUCN/SSC Amphibian Specialist Group, 2011")
  DRAFT_SOURCE = source
else
  DRAFT_SOURCE = Source.create(
    :title => "Draft IUCN/SSC Amphibian Specialist Group, 2011",
    :in_text => "Draft IUCN/SSC Amphibian Specialist Group, 2011",
    :citation => "Draft IUCN/SSC Amphibian Specialist Group, 2011\r\n",
    :url => "http://www.amphibians.org/redlist"
  )
end

if scheme = TaxonScheme.find_by_title("IUCN Red List of Threatened Species. Version 2012.2")
  SCHEME = scheme
else
  SCHEME = TaxonScheme.create(
    :title => "IUCN Red List of Threatened Species. Version 2012.2",
    :description => "IUCN 2012. IUCN Red List of Threatened Species. Version 2012.2. <www.iucnredlist.org>. Downloaded on 13 November 2012.",
    :source_id => SOURCE.id
  )
end

if scheme = TaxonScheme.find_by_title("Draft IUCN/SSC Amphibian Specialist Group, 2011")
  DRAFT_SCHEME = scheme
else
  DRAFT_SCHEME = TaxonScheme.create(
    :title => "Draft IUCN/SSC Amphibian Specialist Group, 2011",
    :description => "Unpublished draft IUCN/SSC Amphibian Specialist Group assessments.",
    :source_id => DRAFT_SOURCE.id
  )
end

#Make a key for returning the Assessment Section titles from the SIS API values
headers = [
  'GeographicRangeInformation',
  'PopulationDocumentation',
  'UseTradeDocumentation',
  'ThreatsDocumentation',
  'ConservationActionsDocumentation',
  'RedListCategory',
  'RedListCriteria',
  'RedListAssessmentDate',
  'RedListRationale',
  'TaxonomicNotes',
  'bibliography',
  'HabitatDocumentation'
]

header_hash = Hash.new
header_hash['GeographicRangeInformation'] = "Geographic Range"
header_hash['PopulationDocumentation'] = "Population"
header_hash['UseTradeDocumentation'] = "Use Trade"
header_hash['ThreatsDocumentation'] = "Threats"
header_hash['ConservationActionsDocumentation'] = "Conservation Actions"
header_hash['RedListRationale'] = "Red List Rationale"
header_hash['TaxonomicNotes'] = "Taxonomy"
header_hash['bibliography'] = "Bibliography"
header_hash['HabitatDocumentation'] = "Habitat"

#Log in to the SIS API
missing = [] #did we miss any?
assessment_keepers = []
assessment_section_keepers = []
unless working_set_species = get_workingset_species(auth_token, OPTS.working_setid)
  puts "No species in that working set"
  exit(0)
end
working_set_species.each do |sp| #Loop through the species in the workingset
  iucn_id = sp['taxonid'].to_s
  iucn_name = sp['name'].gsub('_new','')
  puts "\t Processing #{iucn_name}..."
  unless taxon = Taxon.first(
    :joins => 
      "JOIN taxon_scheme_taxa tst ON tst.taxon_id = taxa.id " +
      "JOIN taxon_schemes ts ON ts.id = tst.taxon_scheme_id",
    :conditions => ["ts.id IN (?) AND tst.source_identifier = ?", [SCHEME.id, DRAFT_SCHEME.id], iucn_id]
  )
    puts "\t\t No taxa in iucn schemes with source_identifir #{iucn_id}, checking other taxa..."
    if taxon = Taxon.first(:conditions => {:name => iucn_name})
      puts "\t\t Found taxon #{iucn_name}..."
    else
      puts "\t\t No taxa in with iucn name #{iucn_name}, attempting to create..."
      if parent = Taxon.first(:conditions => {:name => iucn_name.split[0], :rank => "genus"})
        taxon = Taxon.new(
          :name => iucn_name,
          :rank => 'species',
          :source_identifier => iucn_id,
          :parent_id => parent.id,
          :source_id => DRAFT_SOURCE.id,
          :is_active => false
        )
        if taxon.save
          puts "\t\t Successfully created taxon"
        else
          taxon = nil
        end
      end
    end
    if taxon
      unless taxon_scheme_taxon = TaxonSchemeTaxon.first(:conditions => ["taxon_id = ? AND taxon_scheme_id IN (?)", taxon.id, [SCHEME.id, DRAFT_SCHEME.id]])
        tst = TaxonSchemeTaxon.new(
          :taxon_scheme_id => DRAFT_SCHEME.id,
          :taxon_id => taxon.id,
          :source_identifier => iucn_id
        )
        if tst.save
          puts "\t\t Successfully added taxon to taxon_scheme"
        end
      end
    else
      missing << iucn_id
      puts "\t\t Problem creating taxon for #{iucn_name}"
    end
  end
  
  assessment_id = get_most_recent_assessment_id(auth_token, iucn_id)
  if taxon && assessment_id
    unless assessment = Assessment.first(:conditions => {:taxon_id => taxon.id, :project_id => project.id})
      assessment = Assessment.new(
        :taxon_id => taxon.id,
        :project_id => project.id,
        :user => project.user
      )
      if assessment.save
        puts "\t\t Created assessment for #{taxon.name}"
      else
        puts "\t\t Failed to save assessment: #{assessment.errors.full_messages.to_sentence}"
        next
      end
    end
    assessment_keepers << assessment.id  
    
    if sis_assessment = get_assessment(auth_token, assessment_id)
      for_description = "IUCN RedList Category:" #Start building string to fill in assessment description, in this case a summary of the Assessment
      assessment_date = ""
      sis_assessment.each do |key, value| #loop through the assessment secitons
        if headers.include? key
          if key == "RedListCategory" #rather add this to the assessment description
            for_description = for_description + " " + value if value
          elsif key == "RedListCriteria" #rather add this to the assessment description
            for_description = for_description + " " + value if value
          elsif key == "RedListAssessmentDate" #rather add this to the assessment description
            assessment_date = assessment_date + value if value
          else
            value = "Section empty" if value.nil?
            if key == "GeographicRangeInformation" #add the map to the assessment section
              value = value + "<iframe width=\"100%\" height=\"500\" src=\"http://www.inaturalist.org/taxa/#{taxon.id}/map#5.00/-8.477/-72.039\"></iframe>" ###
            end
            if key == "TaxonomicNotes"
              value = "<table><tr><td>" + taxon.ancestors[1..-1].map{|t| t.name}.join("</td><td>") + "</td><td>" + taxon.name + "</td></tr></table>Taxonomic notes:  " + value
            end
            if key == "bibliography"
              new_value = "<ul>"
              value.each do |cit|
                new_value = new_value + "<li>" + cit["citation"] + "</li>"
              end
              value = new_value + "</ul>"
            end
            if assessment_section = AssessmentSection.first(:conditions => {:assessment_id => assessment.id, :title => header_hash[key]}) 
              assessment_section.update_attributes(:body => value)
            else
              assessment_section = AssessmentSection.new(
                :assessment_id => assessment.id,
                :user => project.user,
                :title => header_hash[key],
                :body => value
              )
              if assessment_section.save
                puts "\t\t Created assessment_section for #{assessment.id}"
              else
                assessment_section = nil
                puts "\t\t Failed to save assessment section: #{assessment_section.errors.full_messages.to_sentence}"
              end
            end
            assessment_section_keepers << assessment_section.id if assessment_section
          end
        else
          puts "\t\t Unrecognized assessment_section header #{key}"
        end
      end
      if assessment_date == ""
        for_description = for_description + " (Draft)"
      else
        for_description = for_description + " (Published on #{assessment_date[0..9]})"
      end
      assessment.update_attributes(:description => for_description)
    end
    
  end
end
puts "Finished processing assessments..."

if missing.count > 0
  puts "The following IUCN IDs are not represented in the respective iNat scheme..."
  missing.each do |m|
    puts "\t#{m}"
  end
end

#remove any assessments and assessment sections no longer in SIS
puts "Removing any assessments and assessment sections no longer in SIS..."
assessment_section_keepers = assessment_section_keepers.compact
assessment_keepers = assessment_keepers.compact
AssessmentSection.all(
  :joins => [:assessment],
  :conditions => ['assessment_sections.id NOT IN (?) AND assessments.project_id = ?', assessment_section_keepers, project.id]
).each do |as|
  puts "\tdestroyed assessment section #{as.id}"
  as.destroy
end
Assessment.all(:conditions => ['id NOT IN (?) AND project_id = ?', assessment_keepers, project.id]).each do |a|
  puts "\tdestroyed assessment #{a.id}"
  a.destroy
end

##
## Subscribe project curators and managers to assessment_sections and Peru Amphibian observations
##
puts "Subscribing project managers and curators to relevant resources"
peru = Place.where(:name => "Peru", :place_type => Place::PLACE_TYPE_CODES['Country']).first
amphibia = Taxon::ICONIC_TAXA_BY_NAME['Amphibia']
if peru && amphibia
  project.project_users.where("role IN ('manager', 'curator')").each do |pu|
    exists = Subscription.where(
      :user_id => pu.user.id, 
      :resource_type => "Place", 
      :resource_id => peru.id, 
      :taxon_id => amphibia.id).exists?
    next if exists
    subscription = Subscription.new(
      :user_id => pu.user_id,
      :resource => peru,
      :taxon => amphibia
    )
    if subscription.save
      puts "\t\t created Peru Amphibs subscription for user #{pu.user.login}"
    else
      puts "\t\t Failed to create Peru Amphibs subscription for #{pu.user.login}: #{subscription.errors.full_messages.to_sentence}"
    end
  end
end

##
## Compile comments on assessment section into a project asset CSV
##

#Update the project asset with a current CSV export of comments
fname = 'peru_forum_comments.csv'
unless pa = ProjectAsset.first(:conditions => {
  :project_id => project.id,
  :asset_file_name => fname,
  :asset_content_type => "text/csv"}
)
  pa = ProjectAsset.new(
    :project_id => project.id,
    :asset_file_name => fname,
    :asset_content_type => "text/csv"
  )
  if pa.save
    puts "\t\t Created Project Asset"
  else
    puts "\t\t Failed to save assessment section: #{pa.errors.full_messages.to_sentence}"
    exit(0)
  end
end
tmp_path = File.join(Rails.root, "/public/attachments/project_assets/#{pa.id}-#{fname}")

#Make csv headers
find_options = {
  :include => [:comments => :user, :assessment => :taxon],
  :joins => [:assessment],
  :conditions => ['assessments.project_id = ?', project.id]
}
zeros = []
fields = []
AssessmentSection.do_in_batches(find_options) do |as|
  unless fields.include? as.title
    fields << as.title
    zeros << 0
  end
end
headers = ['Taxon',fields,'Comment','Time','User']
headers = headers.flatten

puts "Writing comments to csv..."

CSV.open(tmp_path, 'w') do |csv|
  csv << headers
  AssessmentSection.do_in_batches(find_options) do |as|
    ones = zeros.clone
    ones[fields.index(as.title)] = 1 
    as.comments.each do |c| 
      puts "\tWrote comment #{c.id} to csv"
      row = [as.assessment.taxon.name, ones, c.body, c.created_at, c.user.login]
      csv << row.flatten
    end
  end
end
puts
puts "Finished in #{Time.now - start} s"

