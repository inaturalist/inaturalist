class WikimediaPhoto < Photo
  
  Photo.descendent_classes ||= []
  Photo.descendent_classes << self
  
  #return an Wikimedia api response based on a taxon_name
  def self.api_response_from_taxon_name(taxon_name, options = {})
    wm = WikimediaService.new
    api_response = []
    begin
      query_results = wm.query(
        :titles => taxon_name,
        :redirects => '',
        :imlimit => '100',
        :prop => 'images')
    rescue Timeout::Error => e
      query_results = nil
    end
    file_names = []
    unless query_results.blank?
      raw = query_results.at('images')
      filenames = []
      unless raw.nil?
        raw.children.each do |child|
          filename = child.attributes["title"].value
          filenames << filename.strip.gsub(/\s/, '_') if filename.split(".").last.upcase == "JPG"
        end
      else
        w = WikipediaService.new
        t = Taxon.find_by_name(taxon_name)
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
    #"http://commons.wikimedia.org/w/api.php?prop=imageinfo&titles=#{filenames.join("|")}&action=query&format=xml&iiprop=timestamp|user|userid|comment|parsedcomment|url|size|dimensions|sha1|mime|thumbmime|mediatype|metadata|archivename|bitdepth"
    metadata_query_results = wm.query(
      :prop => 'imageinfo',
      :titles => filenames.join("|"),
      :iiprop => 'timestamp|user|userid|comment|parsedcomment|url|size|dimensions|sha1|mime|thumbmime|mediatype|metadata|archivename|bitdepth'
    )
    metadata_query_results.at('pages').children.each do |child|
      file_name = child.attributes['title'].value.strip.gsub(/\s/, '_').split("File:")[1]
      width = child.at('ii').attributes['width'].to_s.to_i
      md5_hash = Digest::MD5.hexdigest(file_name)
      image_url = "http://upload.wikimedia.org/wikipedia/commons/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}"
      large_url = "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}/#{1024 > width ? width : 1024}px-#{file_name}"
      medium_url = "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}/#{500 > width ? width : 500}px-#{file_name}"
      small_url = "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}/#{240 > width ? width : 240}px-#{file_name}"
      square_url = "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}/#{100 > width ? width : 100}px-#{file_name}"
      thumb_url = "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}/#{75 > width ? width : 75}px-#{file_name}"
      native_page_url = "http://commons.wikimedia.org/wiki/File:#{file_name}"
      api_response << {
        :large_url => large_url,
        :medium_url => medium_url,
        :small_url => small_url,
        :thumb_url => thumb_url,
        :native_photo_id => file_name,
        :square_url => thumb_url,
        :original_url => image_url,
        :native_page_url => native_page_url
      }
    end
    return api_response
  end
  
  def self.get_api_response(file_name)
    doc = Nokogiri::HTML(open("http://commons.wikimedia.org/w/index.php?title=File:#{file_name}", 'User-Agent' => 'ruby'))
    if doc.at('#fileinfotpl_aut')
      author = doc.at('#fileinfotpl_aut').parent.elements.last.inner_text
    else
      author = "anonymous"
    end
    license = doc.search('.licensetpl_short').inner_text
    width = doc.at('.fileInfo').inner_html.split("(")[1].split(" ")[0].gsub(",","").to_i 
    md5_hash = Digest::MD5.hexdigest(file_name)
    image_url = "http://upload.wikimedia.org/wikipedia/commons/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}"
    if 1024 > width
      large_url = image_url
    else
      large_url = "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}/1024px-#{file_name}"  
    end
    if 500 > width
      medium_url = image_url
    else
      medium_url = "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}/500px-#{file_name}"
    end
    if 240 > width
      small_url = image_url
    else
      small_url = "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}/240px-#{file_name}"
    end
    square_url = "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}/#{100 > width ? width : 100}px-#{file_name}"
    thumb_url = "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}/#{75 > width ? width : 75}px-#{file_name}"
    native_page_url = "http://commons.wikimedia.org/wiki/File:#{file_name}"
    license_code = nil
    if (license.downcase.include? "public domain") || (license.downcase.include? "pd")
      license_code = 7
    elsif license.downcase.include? "cc-by-nc-sa"
      license_code = 1
    elsif license.downcase.include? "cc-by-nc-nd"
      license_code = 3
    elsif license.downcase.include? "cc-by-nc"
      license_code = 2
    elsif license.downcase.include? "cc-by-sa"
      license_code = 5
    elsif license.downcase.include? "cc-by-nd"
      license_code = 6
    elsif license.downcase.include? "cc-by"
      license_code = 4
    end
    if (license_code == nil) || (author == "anonymous" && ([1,2,3,4,5,6].include? license_code))
      api_response = nil
    else
      api_response = {
        :large_url => large_url,
        :medium_url => medium_url,
        :small_url => small_url,
        :thumb_url => thumb_url,
        :native_photo_id => file_name,
        :square_url => thumb_url,
        :original_url => image_url,
        :native_page_url => native_page_url,
        :native_username => author,
        :native_realname => author,
        :license =>  license_code
      }
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
    wikimedia_photo = WikimediaPhoto.new(options)
    wikimedia_photo
  end

end
