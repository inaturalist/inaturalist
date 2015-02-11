class EolPhoto < Photo
  
  Photo.descendent_classes ||= []
  Photo.descendent_classes << self

  validate :licensed_if_no_user

  def sync
    new_photo = self.class.new_from_api_response(self.class.get_api_response(native_photo_id))
    cols = Photo.column_names - %w(id user_id native_photo_id type created_at updated_at)
    cols.each do |c|
      send("#{c}=", new_photo.send(c))
    end
    save
  end

  def self.search_eol(query, options = {})
    return [] if query.blank?
    eol_page_id = options[:eol_page_id]
    if eol_page_id.blank?
      search_xml = eol.search(query, :exact => 1)
      return [] if search_xml.blank?
      eol_page_id = search_xml.at("entry/id").try(:text)
    end
    return [] if eol_page_id.blank?
    limit = (options[:limit] || 36).to_i
    limit = 100 if limit > 100
    eol_page_xml = begin
      eol.page(eol_page_id, :licenses => 'any', :images => limit, :text => 0, :videos => 0, :details => 1)
    rescue OpenURI::HTTPError => e
      return []
    end
    eol_page_xml.xpath('//xmlns:dataObject[.//xmlns:mediaURL]').map do |data_object|
      new_from_api_response(data_object)
    end.compact
  end
        
  def self.get_api_response(photo_id)
    xml = eol.data_objects(photo_id)
    return nil if xml.at('error')
    xml
  end
  
  def self.new_from_api_response(api_response, options = {})
    api_response.remove_namespaces! if api_response.respond_to?(:remove_namespaces!)
    native_photo_id = api_response.at('dataObjectID').try(:content)
    native_photo_id ||= api_response.at('dataObject identifier').content
    if license = api_response.at('license')
      license_string = api_response.search('license').children.first.inner_text
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
    square_url, thumb_url, small_url, medium_url, original_url = nil
    image_url = api_response.search('mediaURL').children.last.try(:inner_text)
    unless image_url.blank?
      square_url = image_url.gsub("_orig", "_88_88")
      small_url = image_url.gsub("_orig", "_260_190")
      medium_url = image_url.gsub("_orig", "_580_360")
    end
    thumb_url = api_response.search('thumbnailURL').children.last.inner_text
    rights_holder = api_response.search('dataObject rightsHolder')
    if rights_holder.count == 0
      agent = api_response.search('agent[role=creator]').first
      agent ||= api_response.search('agent[role=photographer]').first
      native_username = agent.inner_text if agent
    elsif rights_holder.children.size > 0
      native_username = rights_holder.children.first.inner_text
    else
      native_username = rights_holder.content
    end

    native_page_url = if (verson_id = api_response.at('dataObjectVersionID').try(:content))
      "http://eol.org/data_objects/#{verson_id}"
    elsif (eol_taxon_id = api_response.at('taxon identifier').try(:content))
      "http://eol.org/pages/#{eol_taxon_id}"
    end
    
    new(options.merge(
      :medium_url => medium_url,
      :small_url => small_url,
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
