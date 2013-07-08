module TaxonDescribers
  
  class Wikipedia < Base
    def describe(taxon)
      title = taxon.wikipedia_title
      title = taxon.name if title.blank?
      decoded = ""
      begin
        query_results = wikipedia.query(
          :titles => title, 
          :redirects => '', 
          :prop => 'revisions', 
          :rvprop => 'content')
        raw = query_results.at('page')
        unless raw.blank? || raw['missing']
          parsed = wikipedia.parse(:page => raw['title']).at('text').try(:inner_text).to_s
          decoded = clean_html(parsed)
        end
      rescue Timeout::Error => e
        Rails.logger.info "[INFO] Wikipedia API call failed: #{e.message}"
      end
      decoded
    end

    def clean_html(html, options = {})
      coder = HTMLEntities.new
      decoded = coder.decode(html)
      decoded.gsub!('href="//', 'href="http://')
      decoded.gsub!('src="//', 'src="http://')
      decoded.gsub!('href="/', 'href="http://en.wikipedia.org/')
      decoded.gsub!('src="/', 'src="http://en.wikipedia.org/')
      if options[:strip_references]
        decoded.gsub!(/<sup .*?class=.*?reference.*?>.+?<\/sup>/, '')
        decoded.gsub!(/<strong .*?class=.*?error.*?>.+?<\/strong>/, '')
      end
      decoded
    end

    def wikipedia
      @wikipedia ||= WikipediaService.new(:locale => "en")
    end

    def page_url(taxon)
      wname = taxon.wikipedia_title
      wname = taxon.name.to_s.gsub(/\s+/, '_') if wname.blank?
      URI.encode("http://en.wikipedia.org/wiki/#{wname}")
    end
  end

end
