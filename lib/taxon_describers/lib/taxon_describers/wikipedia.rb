module TaxonDescribers
  
  class Wikipedia < Base
    def initialize( options = {} )
      @locale = options[:locale]
      @page_urls = {}
      super()
    end

    def describe( taxon )
      title = nil
      if Rails.env.production?
        # Redirects from the iNat taxon ID in Wikidata to Wikipedia in a
        # particular locale. We're using it to grab the Wikipedia page title.
        # Note that this will only work with the production database, since
        # those are the taxon IDs Wikidata has ingested, so unfortunately this
        # can't really be tested
        if r = fetch_head( "https://hub.toolforge.org/P3151:#{taxon.id}?lang=#{@locale.to_s.split( "-" ).first}" )
          title = r.header[:location].to_s.split( "/" ).last
          @page_urls[taxon.id] = r.header[:location]
        end
      end
      title = CGI.unescape( title ) unless title.blank?
      title = taxon.wikipedia_title if title.blank?
      title = taxon.name if title.blank?
      decoded = ""
      page_title = title
      begin
        response = wikipedia.parse(:page => title, :redirects => true)
        return if response.nil?
        parsed = response.at('text').try(:inner_text).to_s if response.at('text')
        return if parsed.blank?
        decoded = clean_html(parsed) if parsed
        return if decoded.blank?
        page_title = response.at( "parse" )[:title] if response.at( "parse" )
      rescue Timeout::Error => e
        Rails.logger.info "[INFO] Wikipedia API call failed: #{e.message}"
      end
      decoded + "<p class='inat-wikipedia-attribution'>#{I18n.t(:wikipedia_attribution_cc_by_sa_3_html, url: page_url( taxon ), title: page_title )}</p>"
    end

    def clean_html(html, options = {})
      coder = HTMLEntities.new
      html.gsub!(/(data-)?videopayload=".+?"/m, '')
      decoded = coder.decode(html)
      decoded.gsub!(/href="\/([A-z])/, "href=\"#{wikipedia.base_url}/\\1")
      decoded.gsub!(/src="\/([A-z])/, "src=\"#{wikipedia.base_url}/\\1")
      decoded.gsub!(/<div .*?class=.*?hatnote.*?>.+?<\/div>/, '')
      if options[:strip_references]
        decoded.gsub!(/<sup .*?class=.*?reference.*?>.+?<\/sup>/, '')
        decoded.gsub!(/<strong .*?class=.*?error.*?>.+?<\/strong>/, '')
      end
      decoded
    end

    def wikipedia
      WikipediaService.new( debug: Rails.env.development?, locale: @locale )
    end

    def page_url(taxon)
      if @page_urls && !@page_urls[taxon.id].blank?
        @page_urls[taxon.id]
      elsif Rails.env.production?
        "https://hub.toolforge.org/P3151:#{taxon.id}?lang=#{@locale}"
      else
        wname = taxon.wikipedia_title
        wname = taxon.name.to_s.gsub(/\s+/, '_') if wname.blank?
        wikipedia.url_for_title(wname)
      end
    end
  end

end
