# frozen_string_literal: true

class EolPhoto < Photo
  validate :licensed_if_no_user

  def sync
    new_photo = self.class.new_from_api_response( self.class.get_api_response( native_photo_id ) )
    cols = Photo.column_names - %w(id user_id native_photo_id type created_at updated_at)
    cols.each do | c |
      send( "#{c}=", new_photo.send( c ) )
    end
    save
  end

  def self.search_eol( query, options = {} )
    return [] if query.blank?

    eol_page_id = options[:eol_page_id]
    if eol_page_id.blank?
      search_xml = eol.search( query, exact: 1 )
      return [] if search_xml.blank?

      # exact param does not seem to work as of 2025-05-09, so this tries to
      # find the result that exactly matches the query
      eol_page_id = search_xml.
        search( "//result" ).
        detect {| result | result.at( "title" ).text == query }.
        at( "id" ).text
    end
    return [] if eol_page_id.blank?

    per_page = ( options[:per_page] || 36 ).to_i
    per_page = 100 if per_page > 100
    eol_page_xml = begin
      eol.page( eol_page_id,
        licenses: "all",
        images_page: options[:page],
        images_per_page: per_page,
        maps_per_page: 0,
        texts_per_page: 0,
        videos_per_page: 0,
        sounds_per_page: 0,
        details: 1 )
    rescue OpenURI::HTTPError
      return []
    end
    eol_page_xml.xpath( "//dataObject[.//eolMediaURL]" ).map do | data_object |
      new_from_api_response( data_object )
    end.compact
  end

  def self.get_api_response( photo_id )
    xml = eol.data_objects( photo_id )
    return nil if xml.at( "error" )

    xml
  end

  def self.new_from_api_response( api_response, options = {} )
    api_response.remove_namespaces! if api_response.respond_to?( :remove_namespaces! )
    native_photo_id = api_response.at( "dataObjectVersionID" ).try( :content )
    return unless native_photo_id

    if ( license = api_response.at( "license" ) )
      license_string = license.content
      license_number = Photo::C
      if license_string.include? "publicdomain"
        license_number = PD
      end
      [1, 2, 3, 4, 5, 6].each do | num |
        if license_string.include? "licenses/#{Photo.license_code_for_number( num ).split( 'CC-' )[1].downcase}/"
          license_number = num
        end
      end
    else
      # all EOL content should be CC licensed or PD, so if there's not license info we can assume it's PD
      license_number = PD
    end
    _, _, small_url, medium_url, = nil
    image_url = api_response.at( "eolMediaURL" ).content
    unless image_url.blank?
      small_url = image_url.gsub( /(\.\w+?)$/, ".260x190\\1" )
      medium_url = image_url.gsub( /(\.\w+?)$/, ".580x360\\1" )
    end
    thumb_url = api_response.at( "eolThumbnailURL" ).content
    rights_holder = api_response.search( ".//rightsHolder" )
    if rights_holder.count.zero?
      agent = api_response.search( ".//agent[role[text()='creator']]" ).first
      agent ||= api_response.search( ".//agent[role[text()='photographer']]" ).first
      native_username = agent&.at( "full-name" )&.inner_text
    elsif rights_holder.children.size.positive?
      native_username = rights_holder.children.first.inner_text
    else
      native_username = rights_holder.try( :content )
    end

    native_page_url = if ( source = api_response.at( ".//source" ) )
      source.content
    elsif ( verson_id = api_response.at( "dataObjectVersionID" ).try( :content ) )
      "https://eol.org/media/#{verson_id}"
    elsif ( eol_taxon_id = api_response.at( "taxon/identifier" ).try( :content ) )
      "http://eol.org/pages/#{eol_taxon_id}"
    end

    new( options.merge(
      remote_medium_url: medium_url,
      remote_small_url: small_url,
      remote_thumb_url: thumb_url,
      remote_square_url: thumb_url,
      remote_original_url: image_url,
      native_photo_id: native_photo_id,
      native_page_url: native_page_url,
      native_username: native_username,
      native_realname: native_username,
      license: license_number
    ) )
  end

  def repair( options = {} )
    r = EolPhoto.get_api_response( native_photo_id )
    if r.blank? || r.children.blank?
      return [self, { photo_missing: "photo not found #{self}" }]
    end

    p = EolPhoto.new_from_api_response( r )
    ( EolPhoto.column_names - %w(id created_at updated_at) ).each do | a |
      send( "#{a}=", p.send( a ) )
    end
    save unless options[:no_save]
    [self, {}]
  rescue Timeout::Error
    [self, { timeout: "EOL didn't respond" }]
  end

  def self.eol
    @eol ||= EolService.new( timeout: 10 )
  end
end
