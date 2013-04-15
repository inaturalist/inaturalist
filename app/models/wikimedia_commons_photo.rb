#encoding: utf-8
class WikimediaCommonsPhoto < Photo
  
  Photo.descendent_classes ||= []
  Photo.descendent_classes << self
  
  # retrieve WikimediaCommonsPhotos from Wikimedia Commons based on a taxon_name
  def self.search_wikimedia_for_taxon(taxon_name, options = {})
    wm = WikimediaCommonsService.new
    wikimedia_photos = []
    query_results = begin
      wm.query(
        :titles => taxon_name,
        :redirects => '',
        :imlimit => '100',
        :prop => 'images')
    rescue Timeout::Error => e
      nil
    end
    return unless query_results
    raw = query_results.at('images')
    filenames = if raw.blank?
      taxon = Taxon.find_by_name(taxon_name)
      title = taxon.try(:wikipedia_title) || taxon_name
      [wikipedia_image_filename_for_title(taxon_name)]
    else
      raw.children.map do |child|
        filename = child.attributes["title"].value
        ext = filename.split(".").last.upcase.downcase
        %w(jpg jpef png gif).include?(ext) ? filename.strip.gsub(/\s/, '_') : nil
      end
    end.compact
    metadata_query_results = begin
      wm.query(
        :prop => 'imageinfo',
        :titles => filenames.join("|"),
        :iiprop => 'timestamp|user|userid|comment|parsedcomment|url|size|dimensions|sha1|mime|thumbmime|mediatype|metadata|archivename|bitdepth'
      )
    rescue Timeout::Error => e
      nil
    end
    return if metadata_query_results.blank?
    return if metadata_query_results.at('pages').blank?
    first_page = metadata_query_results.at('pages').children.first
    return if first_page['missing'] || first_page['invalid']
    metadata_query_results.at('pages').children.each do |page|
      file_name = page.attributes['title'].value.strip.gsub(/\s/, '_').split("File:")[1]
      next if file_name.blank?
      next unless page.at('ii') && page.at('ii')['width']
      width = page.at('ii')['width'].to_i
      md5_hash = Digest::MD5.hexdigest(file_name)
      image_url = "http://upload.wikimedia.org/wikipedia/commons/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}"
      large_url = "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}/#{1024 > width ? width : 1024}px-#{file_name}"
      medium_url = "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}/#{500 > width ? width : 500}px-#{file_name}"
      small_url = "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}/#{240 > width ? width : 240}px-#{file_name}"
      square_url = "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}/#{100 > width ? width : 100}px-#{file_name}"
      thumb_url = "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}/#{75 > width ? width : 75}px-#{file_name}"
      native_page_url = "http://commons.wikimedia.org/wiki/File:#{file_name}"
      wikimedia_photos << WikimediaCommonsPhoto.new(
        :large_url => large_url,
        :medium_url => medium_url,
        :small_url => small_url,
        :thumb_url => thumb_url,
        :native_photo_id => file_name,
        :square_url => square_url,
        :original_url => image_url,
        :native_page_url => native_page_url
      )
    end
    wikimedia_photos
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
    url = "http://commons.wikimedia.org/w/index.php?title=File:#{file_name}"
    Nokogiri::HTML(open(url, 'User-Agent' => CONFIG.site_name))
  rescue OpenURI::HTTPError => e
    Rails.logger.error "[ERROR #{Time.now}] Failed to retrieve #{url}: #{e}"
    nil
  end
  
  def self.new_from_api_response(api_response, options = {})
    return if api_response.blank?
    return unless file_name = api_response.at('#firstHeading').children[0].children[0].inner_text
    file_name = file_name.strip.gsub(/\s/, '_').split("File:")[1]

    photo = WikimediaCommonsPhoto.new
    photo.native_page_url = "http://commons.wikimedia.org/wiki/File:#{file_name}"
    photo.native_photo_id = file_name

    license = api_response.search('.licensetpl_short').inner_text
    photo.license = if (license.downcase.include? "public domain") || (license.downcase.include? "pd") || (license.downcase.include? "cc0")
      Photo::PD
    elsif license.downcase.include? "cc-by-nc-sa"
      Photo::CC_BY_NC_SA
    elsif license.downcase.include? "cc-by-nc-nd"
      Photo::CC_BY_NC_ND
    elsif license.downcase.include? "cc-by-nc"
      Photo::CC_BY_NC
    elsif license.downcase.include? "cc-by-sa"
      Photo::CC_BY_SA
    elsif license.downcase.include? "cc-by-nd"
      Photo::CC_BY_ND
    elsif license.downcase.include? "cc-by"
      Photo::CC_BY
    elsif license.downcase.include? "gfdl"
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
    md5_hash = Digest::MD5.hexdigest(file_name)
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
