# frozen_string_literal: true

require ::File.expand_path( "../wikipedia", __FILE__ )

module TaxonDescribers
  class WikipediaEs < Wikipedia
    def wikipedia
      @wikipedia ||= WikipediaService.new( locale: "es" )
    end

    def self.describer_name
      "Wikipedia (ES)"
    end
  end
end
