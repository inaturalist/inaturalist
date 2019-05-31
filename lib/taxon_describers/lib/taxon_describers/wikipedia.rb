module TaxonDescribers
  
  class Wikipedia < Base
    def initialize( options = {} )
      @locale = options[:locale]
      super()
    end

    def describe(taxon)
      title = taxon.wikipedia_title
      title = taxon.name if title.blank?
      decoded = ""
      page_title = title
      begin
        response = wikipedia.parse(:page => title, :redirects => true)
        return if response.nil?
        parsed = response.at('text').try(:inner_text).to_s
        decoded = clean_html(parsed) if parsed
        page_title = response.at( "parse" )[:title]
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
      decoded.gsub!(/<table .*?class=.*?ambox.*?>.+?<\/table>/, '')
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
      wname = taxon.wikipedia_title
      wname = taxon.name.to_s.gsub(/\s+/, '_') if wname.blank?
      wikipedia.url_for_title(wname)
    end
  end

end
