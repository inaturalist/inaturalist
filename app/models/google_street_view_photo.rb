class GoogleStreetViewPhoto < Photo
  before_save :set_license

  def attribution
    I18n.t('copyright.all_rights_reserved', :name => "Google")
  end

  def editable_by?(user)
    false
  end

  def set_license
    self.license = Photo::COPYRIGHT
    true
  end

  def repair( options = {} )
    repair_photo = GoogleStreetViewPhoto.new_from_api_response( GoogleStreetViewPhoto.get_api_response( native_photo_id ) )
    update_attributes(
      thumb_url: repair_photo.thumb_url,
      square_url: repair_photo.square_url,
      small_url: repair_photo.small_url,
      medium_url: repair_photo.medium_url,
      large_url: repair_photo.large_url,
      original_url: repair_photo.original_url,
      native_realname: repair_photo.native_realname,
      native_page_url: repair_photo.native_page_url
    )
    [self, {}]
  end

  def self.get_api_response(native_photo_id, options = {})
    q = native_photo_id.to_s.split('?').last
    Rack::Utils.parse_nested_query(q).symbolize_keys
  end

  def self.new_from_api_response(api_response, options = {})
    base = "http://maps.googleapis.com/maps/api/streetview?"
    params = api_response.merge(:sensor => false)
    w,h = (api_response[:size] || "1x1").split('x').map(&:to_f)
    r = h / w rescue 1
    r = 1 if r > 1 || r <= 0
    z = (2 - (2 * (params[:fov] || 90).to_f / 180.0)).floor
    options.update(
      :thumb_url => "#{base}#{params.merge(:size => "75x#{(75*r).to_i}").map{|k,v| "#{k}=#{v}"}.join('&')}",
      :square_url => "#{base}#{params.merge(:size => "100x100").map{|k,v| "#{k}=#{v}"}.join('&')}",
      :small_url => "#{base}#{params.merge(:size => "240x#{(240*r).to_i}").map{|k,v| "#{k}=#{v}"}.join('&')}",
      :medium_url => "#{base}#{params.merge(:size => "500x#{(500*r).to_i}").map{|k,v| "#{k}=#{v}"}.join('&')}",
      :large_url => "#{base}#{params.merge(:size => "640x#{(640*r).to_i}").map{|k,v| "#{k}=#{v}"}.join('&')}",
      :original_url => "#{base}#{params.map{|k,v| "#{k}=#{v}"}.join('&')}",
      :native_realname => "Google",
      :native_page_url => "https://maps.google.com/?ll=#{params[:location]}&layer=c&cbll=#{params[:location]}&cbp=12,#{params[:heading]},,#{z},#{params[:pitch].to_f * -1}",
      :license => Photo::COPYRIGHT
    )
    options[:native_photo_id] ||= options[:original_url]
    GoogleStreetViewPhoto.new(options)
  end
end
