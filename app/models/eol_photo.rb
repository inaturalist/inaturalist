class EolPhoto < Photo
  
  Photo.descendent_classes ||= []
  Photo.descendent_classes << self

  def sync
    new_photo = self.class.new_from_api_response(self.class.get_api_response(native_photo_id))
    cols = Photo.column_names - %w(id user_id native_photo_id type created_at updated_at)
    cols.each do |c|
      send("#{c}=", new_photo.send(c))
    end
    save
  end

  def self.search_eol(query, options = {})
    eol_taxon_xml = eol.search(query, :exact => 1)
    return nil if eol_taxon_xml.blank?
    eol_taxon_id = eol_taxon_xml.search("id").children.last.inner_text
    limit = (options[:limit] || 36).to_i
    limit = 100 if limit > 100
    eol_page_xml = eol.page(eol_taxon_id, :licenses => 'any', :images => limit, :text => 0, :videos => 0, :details => 1)
    eol_page_xml.search('dataObject').map do |data_object|
      new_from_api_response(data_object)
    end.compact
  end
        
  def self.get_api_response(photo_id)
    xml = eol.data_objects(photo_id)
    return nil if xml.at('error')
    xml
  end
  
  def self.new_from_api_response(api_response, options = {})
    eol_page_xml = api_response
    eol_page_xml.remove_namespaces! if eol_page_xml.respond_to?(:remove_namespaces!)
    native_photo_id = eol_page_xml.at('dataObjectID').try(:content)
    native_photo_id ||= eol_page_xml.at('dataObject identifier').content
    if license = eol_page_xml.at('license')
      license_string = eol_page_xml.search('license').children.first.inner_text
      license_number = Photo::C
      if license_string.include? "licenses/publicdomain/"
        license_number = PD
      end
      [1,2,3,4,5,6].each do |num|
        if license_string.include? "licenses/#{Photo.license_code_for_number(num).split("CC-")[1].downcase}/"
          license_number = num 
        end
      end
    else
      # all EOL content should be CC licensed or PD, so if there's not license info we can assume it's PD
      license_number = PD
    end
    image_url = eol_page_xml.search('mediaURL').children.last.inner_text
    thumb_url = eol_page_xml.search('thumbnailURL').children.last.inner_text
    rights_holder = eol_page_xml.search('dataObject rightsHolder')
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

    native_page_url = if (verson_id = eol_page_xml.at('dataObjectVersionID').try(:content))
      "http://eol.org/data_objects/#{verson_id}"
    elsif (eol_taxon_id = eol_page_xml.at('taxon identifier').try(:content))
      "http://eol.org/pages/#{eol_taxon_id}"
    end
    
    new(options.merge(
      :large_url => image_url,
      :medium_url => image_url,
      :small_url => image_url,
      :thumb_url => thumb_url,
      :native_photo_id => native_photo_id,
      :square_url => thumb_url,
      :original_url => image_url,
      :native_page_url => native_page_url,
      :native_username => native_username,
      :native_realname => native_username,
      :license =>  license_number
    ))
  end

  private
  def self.eol
    @eol ||= EolService.new(:timeout => 10)
  end

end
