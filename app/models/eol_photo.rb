class EolPhoto < Photo
  
  Photo.descendent_classes ||= []
  Photo.descendent_classes << self
  
  #return an array of EOLPhotos directly using an api_response based on the taxon_name
  def self.new_from_taxon_name(taxon_name, options = {})
    eol_taxon_url = "http://eol.org/api/search/#{taxon_name}?exact=1".gsub(" ","%20")
    begin
      eol_taxon_xml = Nokogiri::XML.parse(open(eol_taxon_url).read)
      eol_taxon_id = eol_taxon_xml.search("id").children.last.inner_text
      eol_page_url = "http://eol.org/api/pages/1.0/#{eol_taxon_id}?images=1&text=0&videos=0&details=1"
      eol_page_xml = Nokogiri::XML.parse(open(eol_page_url).read)
      license_string = eol_page_xml.search('license').children.first.inner_text
      license_code = 0
      [1,2,3,4,5,6].each do |num|
        if license_string.include? "licenses/#{Photo.license_code_for_number(num).split("CC-")[1].downcase}/"
          license_code = num 
        end
      end
      api_response = {
        :large_url => eol_page_xml.search('mediaURL').children.last.inner_text,
        :medium_url => eol_page_xml.search('mediaURL').children.last.inner_text, #probably too big
        :small_url => eol_page_xml.search('mediaURL').children.last.inner_text, #probably too big
        :thumb_url => eol_page_xml.search('thumbnailURL').children.last.inner_text,
        :native_photo_id => eol_page_xml.search('dataObjectID').children.first.inner_text,
        :square_url => eol_page_xml.search('thumbnailURL').children.last.inner_text, #not quite square
        :original_url => eol_page_xml.search('mediaURL').children.last.inner_text,
        :native_page_url => "http://eol.org/pages/#{eol_page_xml.search('//dc:identifier')[1].inner_text}/overview",
        :native_username => eol_page_xml.search('agent').children.first.inner_text,
        :native_realname => eol_page_xml.search('agent').children.first.inner_text,
        :license =>  license_code
      }
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
      rescue
        return nil
      end
  end
  
  def self.get_api_response(photo_id)
    begin
      eol_page_url = "http://eol.org/api/data_objects/1.0/#{photo_id}"
      eol_page_xml = Nokogiri::XML.parse(open(eol_page_url).read)
      license_string = eol_page_xml.search('license').children.first.inner_text
      license_code = 0
      [1,2,3,4,5,6].each do |num|
        if license_string.include? "licenses/#{Photo.license_code_for_number(num).split("CC-")[1].downcase}/"
          license_code = num 
        end
      end
      api_response = {
        :large_url => eol_page_xml.search('mediaURL').children.last.inner_text,
        :medium_url => eol_page_xml.search('mediaURL').children.last.inner_text, #probably too big
        :small_url => eol_page_xml.search('mediaURL').children.last.inner_text, #probably too big
        :thumb_url => eol_page_xml.search('thumbnailURL').children.last.inner_text,
        :native_photo_id => photo_id,
        :square_url => eol_page_xml.search('thumbnailURL').children.last.inner_text, #not quite square
        :original_url => eol_page_xml.search('mediaURL').children.last.inner_text,
        :native_page_url => "http://eol.org/pages/#{eol_page_xml.search('//dc:identifier').first.inner_text}/overview",
        :native_username => eol_page_xml.search('agent').children.first.inner_text,
        :native_realname => eol_page_xml.search('agent').children.first.inner_text,
        :license =>  license_code
      }
    rescue
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
