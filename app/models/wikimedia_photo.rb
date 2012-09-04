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
        :prop => 'revisions', 
        :rvprop => 'content')
    rescue Timeout::Error => e
      query_results = nil
    end
    begin
      unless query_results.blank?
        raw = query_results.at('page')
        filenames = []
        galleries = raw.to_s.split("&lt;gallery&gt;")
        if galleries.length == 1
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
                  filenames << image_title.strip.gsub(/\s/, '_')
                end
              end
            end
          end
        else
          (1..(galleries.count-1)).each do |num|
            gallery = galleries[num].split("&lt;/gallery&gt;")[0]
            gallery.split("Image:")[1..(gallery.split("Image:").count)].each do |image|
              filenames << image.split("|")[0].strip.gsub(/\s/, '_')
            end
          end
        end
        filenames[0..10].each do |file_name|
          md5_hash = Digest::MD5.hexdigest(file_name)
          image_url = "http://upload.wikimedia.org/wikipedia/commons/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}"
          large_url = "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}/1024px-#{file_name}"
          url = URI.parse(large_url)
          req = Net::HTTP.new(url.host, url.port)
          res = req.request_head(url.path)
          if res.code == "200"
            medium_url = "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}/500px-#{file_name}"
            small_url = "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}/240px-#{file_name}"
          else
            large_url = image_url
            medium_url = "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}/500px-#{file_name}"
            url = URI.parse(medium_url)
            req = Net::HTTP.new(url.host, url.port)
            res = req.request_head(url.path)
            if res.code == "200"
              small_url = "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}/240px-#{file_name}"
            else
              medium_url = image_url
              small_url = "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}/500px-#{file_name}"
              url = URI.parse(medium_url)
              req = Net::HTTP.new(url.host, url.port)
              res = req.request_head(url.path)
              small_url = image_url unless res.code == "200"
            end
          end
          square_url = "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}/100px-#{file_name}"
          thumb_url = "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}/75px-#{file_name}"
          native_page_url = "http://commons.wikimedia.org/wiki/File:#{file_name}"
          begin
            wm_query_results = wm.query(
              :titles => "File:"+file_name,
              :redirects => '', 
              :prop => 'revisions', 
              :rvprop => 'content')
          rescue Timeout::Error => e
            wm_query_results = nil
          end
          unless wm_query_results.nil?
            wm_raw = wm_query_results.at('page').to_s.gsub(/\s/,"")
            unless wm_raw.blank?
              author = "anonymous"
              permission = nil
              if wm_raw.include? "{{int:license-header}}=={{"
                permission = wm_raw.split("{{int:license-header}}=={{")[1].split("}}")[0]
              elsif  wm_raw.include? "{{int:license}}=={{"
                permission =  wm_raw.split("{{int:license}}=={{")[1].split("}}")[0]
              elsif  wm_raw.include? "===License==={{"
                permission = wm_raw.split("===License==={{")[1].split("}}")[0]
              end
              if permission.nil?
                if (wm_raw.include? "{{Information") && (wm_raw.include? "|Permission=")
                  permission = wm_raw.split("|Permission=")[1].split("|")[0]
                end
              end
              if (wm_raw.include? "{{Information") && (wm_raw.include? "|Author=")
                author = wm_raw[/Author=\[(?:\s+[^\]]+)?(.*?)\]/im]
                unless author.nil?
                  author = author.gsub("Author=\[\[","")
                  author = author.gsub("\]\]","")
                  author = author.gsub("Author=\[","")
                  author = author.gsub("\]","")
                else
                  author = "anonymous"
                end
              end
              
              #get the license
              license_code = nil
              unless permission.nil?
                if permission.downcase.include? "pd"
                  license_code = 7
                elsif permission.downcase.include? "cc-by-nc-sa"
                  license_code = 1
                elsif permission.downcase.include? "cc-by-nc-nd"
                  license_code = 3
                elsif permission.downcase.include? "cc-by-nc"
                  license_code = 2
                elsif permission.downcase.include? "cc-by-sa"
                  license_code = 5
                elsif permission.downcase.include? "cc-by-nd"
                  license_code = 6
                elsif permission.downcase.include? "cc-by"
                  license_code = 4
                end
                unless (license_code == nil) || (author == "anonymous" && ([1,2,3,4,5,6].include? license_code))
                  api_response << {
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
              end
            end
          end
        end
      end
    end
    return api_response
  end
  
  def self.get_api_response(file_name)
    begin
      md5_hash = Digest::MD5.hexdigest(file_name)
      image_url = "http://upload.wikimedia.org/wikipedia/commons/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}"
      large_url = "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}/1024px-#{file_name}"
      url = URI.parse(large_url)
      req = Net::HTTP.new(url.host, url.port)
      res = req.request_head(url.path)
      if res.code == "200"
        medium_url = "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}/500px-#{file_name}"
        small_url = "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}/240px-#{file_name}"
      else
        large_url = image_url
        medium_url = "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}/500px-#{file_name}"
        url = URI.parse(medium_url)
        req = Net::HTTP.new(url.host, url.port)
        res = req.request_head(url.path)
        if res.code == "200"
          small_url = "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}/240px-#{file_name}"
        else
          medium_url = image_url
          small_url = "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}/500px-#{file_name}"
          url = URI.parse(medium_url)
          req = Net::HTTP.new(url.host, url.port)
          res = req.request_head(url.path)
          small_url = image_url unless res.code == "200"
        end
      end
      square_url = "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}/100px-#{file_name}"
      thumb_url = "http://upload.wikimedia.org/wikipedia/commons/thumb/#{md5_hash[0..0]}/#{md5_hash[0..1]}/#{file_name}/75px-#{file_name}"
      native_page_url = "http://commons.wikimedia.org/wiki/File:#{file_name}"
      wm = WikimediaService.new
      wm_query_results = wm.query(
        :titles => "File:"+file_name,
        :redirects => '', 
        :prop => 'revisions', 
        :rvprop => 'content')
      wm_raw = wm_query_results.at('page').to_s.gsub(/\s/,"")
      if wm_raw.blank?
        api_response = nil
      else
        author = "anonymous"
        permission = nil
        if wm_raw.include? "{{int:license-header}}=={{"
          permission = wm_raw.split("{{int:license-header}}=={{")[1].split("}}")[0]
        elsif  wm_raw.include? "{{int:license}}=={{"
          permission =  wm_raw.split("{{int:license}}=={{")[1].split("}}")[0]
        elsif  wm_raw.include? "===License==={{"
          permission = wm_raw.split("===License==={{")[1].split("}}")[0]
        end
        if permission.nil?
          if (wm_raw.include? "{{Information") && (wm_raw.include? "|Permission=")
            permission = wm_raw.split("|Permission=")[1].split("|")[0]
          end
        end
        if (wm_raw.include? "{{Information") && (wm_raw.include? "|Author=")
          author = wm_raw[/Author=\[(?:\s+[^\]]+)?(.*?)\]/im]
          unless author.nil?
            author = author.gsub("Author=\[\[","")
            author = author.gsub("\]\]","")
            author = author.gsub("Author=\[","")
            author = author.gsub("\]","")
          else
            author = "anonymous"
          end
        end
        #get the license
        license_code = nil
        unless permission.nil?
          if permission.downcase.include? "pd"
            license_code = 7
          elsif permission.downcase.include? "cc-by-nc-sa"
            license_code = 1
          elsif permission.downcase.include? "cc-by-nc-nd"
            license_code = 3
          elsif permission.downcase.include? "cc-by-nc"
            license_code = 2
          elsif permission.downcase.include? "cc-by-sa"
            license_code = 5
          elsif permission.downcase.include? "cc-by-nd"
            license_code = 6
          elsif permission.downcase.include? "cc-by"
            license_code = 4
          end
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
      end
    rescue => e
      Rails.logger.error "[ERROR #{Time.now}] Failed to retrieve Wikimedia API response: #{e}"
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
    wikimedia_photo = WikimediaPhoto.new(options)
    wikimedia_photo
  end

end
