require ::File.expand_path('../wikipedia', __FILE__)
module TaxonDescribers
  
  class WikipediaFr < Wikipedia
    def wikipedia
      @wikipedia ||= WikipediaService.new(:locale => "fr")
    end

    def self.describer_name
      "Wikipedia (FR)"
    end

    def page_url(taxon)
      "http://fr.wikipedia.org/wiki/#{taxon.wikipedia_title || taxon.name}"
    end
  end

end
