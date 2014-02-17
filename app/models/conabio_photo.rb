class ConabioPhoto < Photo
  
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

  def self.search_conabio(query, options = {})
    search_json = conabio(:server => 'bdi.conabio.gob.mx:9090', :timeout => 5, :photos => true).search(query)
    return [] if search_json.blank?

    JSON.parse(search_json).map do |resp|
      new_from_api_response(resp)
    end.compact
  end
        
  def self.get_api_response(photo_id)
    json = ConabioService.new(:server => 'bdi.conabio.gob.mx:9090', :timeout => 5, :photos => true, :photo_id => true).search(photo_id)
    return nil if json.blank?
    JSON.parse(json).first
  end

  def self.new_from_api_response(api_response, options = {})
      new(options.merge(
              :large_url => api_response['thumb_url'],
              :medium_url => api_response['thumb_url'],
              :small_url => api_response['thumb_url'],
              :thumb_url => api_response['thumb_url'],
              :native_photo_id => api_response['native_photo_id'],
              :square_url => api_response['thumb_url'],
              :original_url => api_response['thumb_url'],
              :native_page_url => api_response['native_page_url'],
              :native_username => api_response['native_username'],
              :native_realname => api_response['native_username'],
              :license => api_response['license_number'].to_i
          ))
  end

  private
  def self.conabio(options = {})
    @conabio ||= ConabioService.new(options)
  end

end
