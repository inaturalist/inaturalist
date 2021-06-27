module TaxonDescribers
  
  class Wikipedia < Base
    def initialize( options = {} )
      @locale = options[:locale]
      @page_urls = {}
      super()
    end

    def describe( taxon )
      title = nil
      page_title = title
      content = nil
      if Rails.env.production?
        # Redirects from the iNat taxon ID in Wikidata to Wikipedia in a
        # particular locale. We're using it to grab the Wikipedia page title.
        # Note that this will only work with the production database, since
        # those are the taxon IDs Wikidata has ingested, so unfortunately this
        # can't really be tested
        lang = @locale.to_s.split( "-" ).first
        if wikipedia_url = wikidata_wikipedia_url_for_taxon( taxon )
          title = wikipedia_url.to_s.split( "/" ).last
          # If we got a title from Wikidata, try to retrieve content for that
          unless title.blank?
            title = CGI.unescape( title )
            page_title, content = content_for_title( title )
            @page_urls[taxon.id] = wikipedia_url unless content.blank?
          end
        end
      end
      # If we didn't get any content from a Wikidata-specified Wikipedia title,
      # fall back to using the taxon data
      if content.blank?
        title = taxon.wikipedia_title if title.blank?
        title = taxon.name if title.blank?
        page_title, content = content_for_title( title )
      end
      return if content.blank?
      content + "<p class='inat-wikipedia-attribution'>#{I18n.t(:wikipedia_attribution_cc_by_sa_3_html, url: page_url( taxon ), title: page_title )}</p>"
    end

    def clean_html(html, options = {})
      coder = HTMLEntities.new
      html.gsub!(/(data-)?videopayload=".+?"/m, '')
      decoded = coder.decode(html)
      decoded.gsub!(/href="\/([A-z])/, "href=\"#{wikipedia.base_url}/\\1")
      decoded.gsub!(/src="\/([A-z])/, "src=\"#{wikipedia.base_url}/\\1")
      doc = Nokogiri::HTML::DocumentFragment.parse( decoded )
      selectors_to_remove = [
        ".hatnote",
        ".infobox.biota",
        ".mw-editsection",
        ".navbar",
        ".taxobox",
        ".taxobox_v3"
      ]
      if options[:strip_references]
        selectors_to_remove << ".reference"
        selectors_to_remove << ".error"
      end
      selectors_to_remove.each do |selector|
        doc.css( selector ).remove
      end
      doc.to_s
    end

    def wikipedia
      WikipediaService.new( debug: Rails.env.development?, locale: @locale )
    end

    def page_url(taxon)
      url = if @page_urls && !@page_urls[taxon.id].blank?
        @page_urls[taxon.id]
      end
      url ||= if Rails.env.production?
        if wikipedia_url = wikidata_wikipedia_url_for_taxon( taxon )
          title = wikipedia_url.to_s.split( "/" ).last
          @page_urls[taxon.id] = wikipedia_url
        end
      end
      if url.blank?
        wname = taxon.wikipedia_title
        wname = taxon.name.to_s.gsub(/\s+/, '_') if wname.blank?
        url = wikipedia.url_for_title(wname)
      end
      url
    end

    private

    def content_for_title( title )
      page_title = title
      begin
        response = wikipedia.parse( page: title, redirects: true )
        return [title, nil] if response.nil?
        parsed = response.at( "text" ).try(:inner_text).to_s if response.at( "text" )
        return [title, nil] if parsed.blank?
        content = clean_html( parsed ) if parsed
        return [title, nil] if content.blank?
        page_title = response.at( "parse" )[:title] if response.at( "parse" )
      rescue Timeout::Error => e
        Rails.logger.info "[INFO] Wikipedia API call failed: #{e.message}"
      end
      [page_title, content]
    end

    def wikidata_wikipedia_url_for_taxon( taxon )
      lang = @locale.to_s.split( "-" ).first
      Rails.cache.fetch( "wikidata_wikipedia_url_for_taxon-#{taxon.id}-#{lang}", expires_in: 1.day ) do
        Timeout::timeout( 5 ) do
          if r = fetch_head( "https://hub.toolforge.org/P3151:#{taxon.id}?lang=#{lang}" )
            if r.header[:location].blank?
              nil
            else
              uri = URI.parse( r.header[:location].to_s ) rescue nil
              if uri && uri.host.split( "." )[0] == lang
                r.header[:location]
              else
                nil
              end
            end
          else
            nil
          end
        rescue Timeout::Error
          nil
        end
      end
    end
  end

end
