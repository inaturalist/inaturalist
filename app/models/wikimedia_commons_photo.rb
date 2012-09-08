class WikimediaCommonsPhoto < Photo
  
  Photo.descendent_classes ||= []
  Photo.descendent_classes << self
  
  # retrieve WikimediaCommonsPhotos from Wikimedia Commons based on a taxon_name
  def self.search_wikimedia_for_taxon(taxon_name, options = {})
    wm = WikimediaCommonsService.new
    wikimedia_photos = []
    begin
      query_results = wm.query(
        :titles => taxon_name,
        :redirects => '',
        :imlimit => '100',
        :prop => 'images')
    rescue Timeout::Error => e
      query_results = nil
    end
    filenames = []
    unless query_results.blank?
      raw = query_results.at('images')
      unless raw.blank?
        raw.children.each do |child|
          filename = child.attributes["title"].value
          filenames << filename.strip.gsub(/\s/, '_') if filename.split(".").last.upcase == "JPG"
        end
      else
        w = WikipediaService.new
        return unless t = Taxon.find_by_name(taxon_name)
        begin
          query_results = w.query(
            :titles => t.wikipedia_title.blank? ? t.name : t.wikipedia_title,
            :redirects => '',
            :prop => 'revisions',
            :rvprop => 'content'
          )
        rescue Timeout::Error => e
          query_results = nil
        end
        unless query_results .nil?
          raw = query_results.at('page')
          unless raw.blank?
            if taxobox = raw.to_s[/\{\{[^\|^\}]*Taxobox(.*)\}\}/im, 1]
              image_title = taxobox[/image\s*=\s*([^\|^\}]*)/i, 1]
              unless image_title.blank?
                filenames << "File:"+image_title.strip.gsub(/\s/, '_')
              end
            end
          end
        end
      end
    end
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
    metadata_query_results.at('pages').children.each do |child|
      file_name = child.attributes['title'].value.strip.gsub(/\s/, '_').split("File:")[1]
      begin
        width = child.try.at('ii').attributes['width'].to_s.to_i
      rescue
        next
      end
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
  
  def self.get_api_response(file_name)
    Nokogiri::HTML(open("http://commons.wikimedia.org/w/index.php?title=File:#{file_name}", 'User-Agent' => 'ruby'))
  end
  
  def self.new_from_api_response(api_response, options = {})
    return if api_response.blank?
    if file_name = api_response.at('#firstHeading').children[0].children[0].inner_text
      file_name = file_name.strip.gsub(/\s/, '_').split("File:")[1]
    else
      return nil
    end
    author = if api_response.at('#fileinfotpl_aut')
      author_elt = api_response.at('#fileinfotpl_aut').parent.elements.last
      author_elt.elements.size > 0 ? author_elt.elements.first.inner_text : author_elt.inner_text
    else
      "anonymous"
    end
    license = api_response.search('.licensetpl_short').inner_text
    width = api_response.at('.fileInfo').inner_html.split("(")[1].split(" ")[0].gsub(",","").to_i 
    md5_hash = Digest::MD5.hexdigest(file_name)
    image_url = "http://upload.wikimedia.org/wikipedia/commons/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}"
    large_url = if width > 1024
      "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}/1024px-#{file_name}"  
    end
    medium_url = if width > 500
      "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}/500px-#{file_name}"
    end
    small_url = if width > 240
      "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}/240px-#{file_name}"
    end
    square_url = "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}/#{100 > width ? width : 100}px-#{file_name}"
    thumb_url = "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}/#{75 > width ? width : 75}px-#{file_name}"
    native_page_url = "http://commons.wikimedia.org/wiki/File:#{file_name}"
    license_code = if (license.downcase.include? "public domain") || (license.downcase.include? "pd")
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
    end
    return if license_code.blank?
    WikimediaCommonsPhoto.new(
      :large_url => large_url,
      :medium_url => medium_url,
      :small_url => small_url,
      :thumb_url => thumb_url,
      :native_photo_id => file_name,
      :square_url => square_url,
      :original_url => image_url,
      :native_page_url => native_page_url,
      :native_username => author,
      :native_realname => author,
      :license => license_code
    )
  end
  
end
