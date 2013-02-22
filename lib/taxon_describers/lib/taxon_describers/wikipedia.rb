module TaxonDescribers
  
  class Wikipedia < Base
    def describe(taxon)
      title = taxon.wikipedia_title
      title = taxon.name if title.blank?
      coder = HTMLEntities.new
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
          decoded = coder.decode(parsed)
          decoded.gsub!('href="//', 'href="http://')
          decoded.gsub!('src="//', 'src="http://')
          decoded.gsub!('href="/', 'href="http://en.wikipedia.org/')
          decoded.gsub!('src="/', 'src="http://en.wikipedia.org/')
        end
      rescue Timeout::Error => e
        Rails.logger.info "[INFO] Wikipedia API call failed: #{e.message}"
      end
      decoded
    end

    def wikipedia
      @wikipedia ||= WikipediaService.new
    end

    def page_url(taxon)
      "http://en.wikipedia.org/wiki/#{taxon.wikipedia_title || taxon.name}"
    end
  end

end
