class EolPhoto < Photo
  
  Photo.descendent_classes ||= []
  Photo.descendent_classes << self
  
  #return an EOL api response based on a taxon_name
  def self.api_response_from_taxon_name(taxon_name, options = {})
    eol_taxon_url = "http://eol.org/api/search/#{taxon_name}?exact=1".gsub(" ","%20")
    begin
      eol_taxon_xml = Nokogiri::XML.parse(open(eol_taxon_url).read)
      eol_taxon_id = eol_taxon_xml.search("id").children.last.inner_text
      eol_page_url = "http://eol.org/api/pages/1.0/#{eol_taxon_id}?licenses=any&images=10&text=0&videos=0&details=1"
      eol_page_xml = Nokogiri::XML.parse(open(eol_page_url).read)
      
      api_response = []
      native_page_url = "http://eol.org/pages/#{eol_page_xml.search('//dc:identifier')[1].inner_text}/overview"
      photo_data_objects = eol_page_xml.search('dataObjectID').children
      photo_count = photo_data_objects.count      
      (0..(photo_count-1)).each do |child|
        #get the data object id and username
        photo_data_object = photo_data_objects[child].inner_text
        #EOL API makes it really hard to find this in an array - since we don't display licensing
        #in photo_fields I'm setting it to nil
        native_username = nil
        
        #get the license
        license_string = eol_page_xml.search('license').children[child].inner_text
        license_code = 0
        if license_string.include? "licenses/pd/"
          license_code = 7
        end
        [1,2,3,4,5,6].each do |num|
          if license_string.include? "licenses/#{Photo.license_code_for_number(num).split("CC-")[1].downcase}/"
            license_code = num 
          end
        end
        
        #get the image_urls
        image_url = eol_page_xml.search('mediaURL').children[child*2-1].inner_text
        thumb_url = eol_page_xml.search('thumbnailURL').children[child].inner_text
  
        api_response << {
          :large_url => image_url,
          :medium_url => image_url,
          :small_url => image_url,
          :thumb_url => thumb_url,
          :native_photo_id => photo_data_object,
          :square_url => thumb_url,
          :original_url => image_url,
          :native_page_url => native_page_url,
          :native_username => native_username,
          :native_realname => native_username,
          :license =>  license_code
        }
      end
    rescue
      api_response = nil
    end
    return api_response
  end  
        
  def self.get_api_response(photo_id)
    begin
      eol_page_url = "http://eol.org/api/data_objects/1.0/#{photo_id}"
      eol_page_xml = Nokogiri::XML.parse(open(eol_page_url).read)
      license_string = eol_page_xml.search('license').children.first.inner_text
      license_code = 0
      if license_string.include? "licenses/publicdomain/"
        license_code = 7
      end
      [1,2,3,4,5,6].each do |num|
        if license_string.include? "licenses/#{Photo.license_code_for_number(num).split("CC-")[1].downcase}/"
          license_code = num 
        end
      end
      image_url = eol_page_xml.search('mediaURL').children.last.inner_text
      thumb_url = eol_page_xml.search('thumbnailURL').children.last.inner_text
      rights_holder = eol_page_xml.search('//dcterms:rightsHolder')
      if rights_holder.count == 0
        alternate_username = eol_page_xml.search('agent')
        native_username = alternate_username[0].inner_text
        if alternate_username.count > 1
          if alternate_username[1]["role"] == "photographer"
            native_username = alternate_username[1].inner_text
          end
        end
      else
        native_username = rights_holder.children.first.inner_text
      end
      
      api_response = {
        :large_url => image_url,
        :medium_url => image_url,
        :small_url => image_url,
        :thumb_url => thumb_url,
        :native_photo_id => photo_id,
        :square_url => thumb_url,
        :original_url => image_url,
        :native_page_url => "http://eol.org/pages/#{eol_page_xml.search('//dc:identifier').first.inner_text}/overview",
        :native_username => native_username,
        :native_realname => native_username,
        :license =>  license_code
      }
    rescue => e
      Rails.logger.error "[ERROR #{Time.now}] Failed to retrieve EOL API response: #{e}"
      api_response = nil
    end
    return api_response
  end
  
  def self.new_from_api_response(api_response, options = {})
    return nil if api_response.nil?
    options.update(
      :large_url => api_response[:large_url],
      :medium_url => api_response[:medium_url],
      :small_url => api_response[:small_url],
      :thumb_url => api_response[:thumb_url],
      :native_photo_id => api_response[:native_photo_id],
      :square_url => api_response[:square_url],
      :original_url => api_response[:original_url],
      :native_page_url => api_response[:native_page_url],
      :native_username => api_response[:native_username],
      :native_realname => api_response[:native_realname],
      :license => api_response[:license]
    )
    eol_photo = EolPhoto.new(options)
    eol_photo
  end

end
