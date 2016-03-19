#encoding: utf-8
class WikimediaCommonsPhoto < Photo
  validate :licensed_if_no_user
  
  # retrieve WikimediaCommonsPhotos from Wikimedia Commons based on a taxon_name
  def self.search_wikimedia_for_taxon(taxon_name, options = {})
    wm = WikimediaCommonsService.new(:debug => true)
    wikimedia_photos = []
    page = options[:page].to_i
    page = 1 if page <= 1
    per_page = (options[:per_page] || options[:limit]).to_i
    per_page = 30 if per_page <= 1
    limit = per_page
    offset = page * per_page - per_page
    query_results = begin
      wm.query(
        :generator => "search",
        :gsrsearch => taxon_name,
        :gsrnamespace => 6,
        :prop => "imageinfo",
        :iiprop => "size|mime|url",
        :gsrlimit => limit,
        :gsroffset => offset)
    rescue Timeout::Error => e
      nil
    end
    return unless query_results
    images = query_results.search('ii').select {|ii| ii['descriptionurl'][/File:.+/,0] =~ /\.(jpg|jpeg|png|gif)/i}
    if images.blank? && (taxon = Taxon.find_by_name(taxon_name))
      title = taxon.try(:wikipedia_title) || taxon_name
      if filename = wikipedia_image_filename_for_title(taxon_name)
        [new_from_api_response(get_api_response(filename))]
      end
    else
      images.map do |ii|
        file_name = ii['descriptionurl'][/File:(.+)/,1]
        next if file_name.blank?
        width = ii['width'].to_i
        next if width == 0
        md5_hash = Digest::MD5.hexdigest(URI.unescape(file_name)) 
        WikimediaCommonsPhoto.new(
          :native_photo_id => file_name,
          :original_url => "http://upload.wikimedia.org/wikipedia/commons/#{md5_hash[0]}/#{md5_hash[0..1]}/#{file_name}",
          :large_url => "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0]}/#{md5_hash[0..1]}/#{file_name}/#{1024 > width ? width : 1024}px-#{file_name}",
          :medium_url => "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0]}/#{md5_hash[0..1]}/#{file_name}/#{500 > width ? width : 500}px-#{file_name}",
          :small_url => "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0]}/#{md5_hash[0..1]}/#{file_name}/#{240 > width ? width : 240}px-#{file_name}",
          :square_url => "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0]}/#{md5_hash[0..1]}/#{file_name}/#{100 > width ? width : 100}px-#{file_name}",
          :thumb_url => "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0]}/#{md5_hash[0..1]}/#{file_name}/#{75 > width ? width : 75}px-#{file_name}",
          :native_page_url => "http://commons.wikimedia.org/wiki/File:#{file_name}"
        )
      end.compact
    end
  end

  def self.wikipedia_image_filename_for_title(title)
    w = WikipediaService.new
    query_results = begin
      w.query(
        :titles => title,
        :redirects => '',
        :prop => 'revisions',
        :rvprop => 'content'
      )
    rescue Timeout::Error => e
      nil
    end
    return if query_results.blank?
    return unless raw = query_results.at('page')
    return unless taxobox = raw.to_s[/\{\{[^\|^\}]*Taxobox(.*)\}\}/im, 1]
    return unless image_title = taxobox[/image\s*=\s*([^\|^\}]*)/i, 1]
    "File:"+image_title.strip.gsub(/\s/, '_')
  end
  
  def self.get_api_response(file_name)
    url = "https://commons.wikimedia.org/w/index.php?title=File:#{file_name}"
    opts = {'User-Agent' => "iNaturalist"}
    opts[:ssl_ca_cert] = CONFIG.ca_file if CONFIG.ca_file
    Nokogiri::HTML(open(url, opts))
  rescue OpenURI::HTTPError => e
    Rails.logger.error "[ERROR #{Time.now}] Failed to retrieve #{url}: #{e}"
    nil
  end
  
  def self.new_from_api_response(api_response, options = {})
    return if api_response.blank?
    file_name = api_response.at('link[rel=canonical]').try(:[], 'href')
    file_name ||= api_response.at('#firstHeading').children[0].children[0].inner_text
    return unless file_name
    file_name = file_name.strip.gsub(/\s/, '_').split("File:")[1]

    photo = WikimediaCommonsPhoto.new
    photo.native_page_url = "http://commons.wikimedia.org/wiki/File:#{file_name}"
    photo.native_photo_id = file_name

    license = api_response.search('.licensetpl_short').inner_text.to_s.downcase
    license_code = license.gsub(/\s/, '-')
    photo.license = if (license.include? "public domain") || (license.include? "pd") ||
                       (license.include? "cc0") || (license.include? "no restrictions")
      Photo::PD
    elsif license_code.include? "cc-by-nc-sa"
      Photo::CC_BY_NC_SA
    elsif license_code.include? "cc-by-nc-nd"
      Photo::CC_BY_NC_ND
    elsif license_code.include? "cc-by-nc"
      Photo::CC_BY_NC
    elsif license_code.include? "cc-by-sa"
      Photo::CC_BY_SA
    elsif license_code.include? "cc-by-nd"
      Photo::CC_BY_ND
    elsif license_code.include? "cc-by"
      Photo::CC_BY
    elsif license_code.include? "gfdl"
      Photo::GFDL
    end
    return photo if photo.license.blank?

    author = if api_response.at('#fileinfotpl_aut')
      author_elt = api_response.at('#fileinfotpl_aut').parent.elements.last
      if author_elt.elements.size > 0
        author_elt.elements.search('a, span').first.try(:inner_text) || author_elt.inner_text
      else
        author_elt.inner_text
      end
    elsif api_response.at('.licensetpl_attr')
      api_response.at('.licensetpl_attr').inner_text
    else
      "anonymous"
    end
    photo.native_username = author
    photo.native_realname = author

    width = api_response.at('.fileInfo').inner_html.split("(")[1].split(" ")[0].gsub(",","").to_i
    md5_hash = Digest::MD5.hexdigest(URI.unescape(file_name))
    url_base = "http://upload.wikimedia.org/wikipedia/commons"
    url_identifier = "#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}"
    photo.original_url = "#{url_base}/#{url_identifier}"
    %w(large medium).each do |size_name|
      size = Photo.const_get(size_name.upcase)
      if width > size
        photo.send("#{size_name}_url=", "#{url_base}/thumb/#{url_identifier}/#{size}px-#{file_name}")
      elsif width == size
        photo.send("#{size_name}_url=", photo.original_url)
      end
    end
    %w(small square thumb).each do |size_name|
      size = Photo.const_get(size_name.upcase)
      photo.send("#{size_name}_url=", "#{url_base}/thumb/#{url_identifier}/#{[size, width-1].min}px-#{file_name}")
    end
    photo
  end
  
end
