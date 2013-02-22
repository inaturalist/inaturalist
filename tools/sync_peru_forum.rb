#This script uses the IUCN SIS API to sync the assessments in Project 626 with a workingset

#Load in the taxon schemes
unless scheme = TaxonScheme.find_by_title('IUCN Red List of Threatened Species. Version 2012.2')
  puts "Can't find the IUCN taxon_scheme"
  exit(0)
end

unless draft_scheme = TaxonScheme.find_by_title('Draft IUCN/SSC Amphibian Specialist Group, 2011')
  puts "Can't find the Draft IUCN taxon_scheme"
  exit(0)
end

#Get the project
unless project = Project.find_by_id('626')
  puts "Can't find the project"
  exit(0)
end

#Make a key for returning the Assessment Section titles from the SIS API values
headers = ['GeographicRangeInformation','PopulationDocumentation','UseTradeDocumentation','ThreatsDocumentation','ConservationActionsDocumentation','RedListCategory','RedListCriteria','RedListAssessmentDate','RedListRationale'] 
header_hash = Hash.new
header_hash['GeographicRangeInformation'] = "Geographic Range"
header_hash['PopulationDocumentation'] = "Population"
header_hash['UseTradeDocumentation'] = "Use Trade"
header_hash['ThreatsDocumentation'] = "Threats"
header_hash['ConservationActionsDocumentation'] = "Conservation Actions"
header_hash['RedListRationale'] = "Red List Rationale"

#Log in to the SIS API
postData = Net::HTTP.post_form(URI.parse('http://api-dev.iucnsis.org/login'),{'username'=>'loarie@gmail.com','password'=>'changeme'})
auth_token = JSON.parse postData.body
response = Net::HTTP.get_response(URI.parse("http://api-dev.iucnsis.org/workingsets?key=#{auth_token['auth_token']}"))
working_sets = JSON.parse response.body
missing = [] #did we miss any?
assessment_keepers = []
assessment_section_keepers = []
working_sets['working_sets'].each do |ws|
  if ws['working_setid'] == 22592492
    puts "Found workingset #{ws['working_setid']}"
    #Get the species in the workingset
    response = Net::HTTP.get_response(URI.parse("http://api-dev.iucnsis.org/workingsets/#{ws['working_setid']}/species?key=#{auth_token['auth_token']}"))
    species = JSON.parse response.body
    species["species"].each do |sp| #Loop through the species
      puts "\t Processing #{sp['name']}"
      unless taxon = Taxon.first(
        :joins => 
          "JOIN taxon_scheme_taxa tst ON tst.taxon_id = taxa.id " +
          "JOIN taxon_schemes ts ON ts.id = tst.taxon_scheme_id",
        :conditions => ["ts.id IN (?) AND tst.source_identifier = ?", [scheme.id, draft_scheme.id], sp['taxonid'].to_s]
      )
        missing << sp['taxonid']
        puts "\t\t No iNat taxon_scheme_taxon reprenting IUCN_ID #{sp['taxonid']}, skipping..."
        next
      end
      #Get the assessments for that species
      response = Net::HTTP.get_response(URI.parse("http://api-dev.iucnsis.org/assessments/#{sp['taxonid']}?key=#{auth_token['auth_token']}"))
      assessments = JSON.parse response.body
      assessment_num = 0 #to make sure we pick the most recent assessment if there are more than one
      assessments["assessments"].each do |as|
        assessment_num = as['id'] if as['id'] > assessment_num
      end
      unless assessment_num > 0 #as long as there's an assessment
        puts "\t\t No assessments in SIS for #{sp['taxonid']}, skipping..."
        next
      end
      unless assessment = Assessment.first(:conditions => {:taxon_id => taxon.id, :project_id => project.id})
        assessment = Assessment.new(
          :taxon_id => taxon.id,
          :project_id => project.id,
          :user_id => 11599
        )
        if assessment.save
          puts "\t\t Created assessment for #{taxon.name}"
        else
          puts "\t\t Failed to save assessment: #{assessment.errors.full_messages.to_sentence}"
          exit(0)
        end
      end
      assessment_keepers << assessment.id #keep this assessment
      
      #Make the taxonomy assessment_section (not in SIS)
      value = taxon.ancestors.map{|t| t.name}.join("; ")
      value = value + "; " + taxon.name
      if assessment_section = AssessmentSection.first(:conditions => {:assessment_id => assessment.id, :title => 'Taxonomy'}) 
        assessment_section.update_attributes(:body => value)
      else
        assessment_section = AssessmentSection.new(
          :assessment_id => assessment.id,
          :user_id => 11599,
          :title => 'Taxonomy',
          :body => value
        )
        if assessment_section.save
          puts "\t\t Created assessment_section for #{assessment.id}"
        else
          puts "\t\t Failed to save assessment section: #{assessment_section.errors.full_messages.to_sentence}"
          exit(0)
        end
      end
      assessment_section_keepers << assessment_section.id #keep this one
      
      #Loop through the assessment sections in SIS
      assessments["assessments"].each do |as|
        if as['id'] == assessment_num #is the most recent assessment if there are more than one
          for_description = "RedList Category:" #Start building string to fill in assessment description, in this case a summary of the Assessment
          assessment_date = ""
          #Get the assessment
          response = Net::HTTP.get_response(URI.parse("http://api-dev.iucnsis.org/assessments/#{as['id']}/details?key=#{auth_token['auth_token']}"))
          details = JSON.parse response.body
          details["details"].each do |key, value| #loop through the assessment secitons
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
                if assessment_section = AssessmentSection.first(:conditions => {:assessment_id => assessment.id, :title => header_hash[key]}) 
                  assessment_section.update_attributes(:body => value)
                else
                  assessment_section = AssessmentSection.new(
                    :assessment_id => assessment.id,
                    :user_id => 11599,
                    :title => header_hash[key],
                    :body => value
                  )
                  if assessment_section.save
                    puts "\t\t Created assessment_section for #{assessment.id}"
                  else
                    puts "\t\t Failed to save assessment section: #{assessment_section.errors.full_messages.to_sentence}"
                    exit(0)
                  end
                end
                assessment_section_keepers << assessment_section.id #keep this one
              end
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
pus = ProjectUser.all(:include => :user, :conditions => ["project_id = ? AND role IN (?)", project.id, ["manager","curator"]])
pus.each do |pu|
  unless subscription = Subscription.first(:conditions => { :user_id => pu.user.id, :resource_type => "Place", :taxon_id => 20978 })
    if subscription = Subscription.create(
      :user_id => pu.user.id,
      :resource_type => "Place",
      :resource_id => 7513,
      :taxon_id => 20978
    )
      puts "\t\t created Peru Amphibs subscription for user #{pu.user.id}"
    else
      puts "\t\t Failed to create Peru Amphibs subscription for #{pu.user.id}: #{subscription.errors.full_messages.to_sentence}"
    end
  end
end
AssessmentSection.all(
  :joins => [:assessment],
  :conditions => ['assessments.project_id = ?', project.id]
).each do |as|
  pus.each do |pu|
    unless subscription = Subscription.first(
      :conditions => {
        :user_id => pu.user.id,
        :resource_type => "AssessmentSection",
        :resource_id => as.id
      }
    )
      if subscription = Subscription.create(
        :user_id => pu.user.id,
        :resource_type => "AssessmentSection",
        :resource_id => as.id
      )
        puts "\t\t created subscription for user #{pu.user.id} and assessment section #{as.id}"
      else
        puts "\t\t Failed to create subscription for #{pu.user.id} and assessment section #{as.id}: #{subscription.errors.full_messages.to_sentence}"
      end
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

puts "Finished!"

