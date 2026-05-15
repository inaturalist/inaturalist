# frozen_string_literal: true

require "spec_helper"

describe WikipediaService do
  describe "initialize" do
    it "returns an instance of WikipediaService" do
      expect( WikipediaService.new ).to be_a WikipediaService
    end

    it "configures api_endpoint attributes based on locale" do
      service = WikipediaService.new( locale: "es" )
      expect( service.api_endpoint ).to be_a ApiEndpoint
      expect( service.api_endpoint.title ).to eq "Wikipedia (ES)"
      expect( service.api_endpoint.documentation_url ).to eq "https://es.wikipedia.org/w/api.php"
      expect( service.api_endpoint.base_url ).to eq "https://es.wikipedia.org/w/api.php?"
    end

    it "defaults to using EN locale" do
      service = WikipediaService.new
      expect( service.api_endpoint ).to be_a ApiEndpoint
      expect( service.api_endpoint.title ).to eq "Wikipedia (EN)"
      expect( service.api_endpoint.documentation_url ).to eq "https://en.wikipedia.org/w/api.php"
      expect( service.api_endpoint.base_url ).to eq "https://en.wikipedia.org/w/api.php?"
    end

    it "configures a default endpoint value for cache_hours" do
      service = WikipediaService.new
      expect( service.api_endpoint.cache_hours ).to eq WikipediaService::CACHE_HOURS
    end

    it "resets endpoint cache_hours if somehow modified" do
      service = WikipediaService.new
      service.api_endpoint.update( cache_hours: WikipediaService::CACHE_HOURS + 10 )
      expect( service.api_endpoint.cache_hours ).to eq WikipediaService::CACHE_HOURS + 10
      expect( ApiEndpoint.count ).to eq 1

      service = WikipediaService.new
      expect( service.api_endpoint.cache_hours ).to eq WikipediaService::CACHE_HOURS
      expect( ApiEndpoint.count ).to eq 1

      # verifying a duplicate ApiEndpoint was not created with a different value
      # of cache_hours, rather the value was update on the existing record
      api_endpoint = ApiEndpoint.first
      expect( api_endpoint.title ).to eq "Wikipedia (EN)"
      expect( api_endpoint.cache_hours ).to eq WikipediaService::CACHE_HOURS
    end
  end

  describe "summary_from_parsed" do
    let( :service ) { WikipediaService.new( locale: "fr" ) }

    def parsed_doc_for( html )
      Nokogiri::XML( "<api><parse><text>#{ERB::Util.h( html )}</text></parse></api>" )
    end

    it "ignores subtitle and style noise before the lead paragraph" do
      html = <<~HTML
        <div class="mw-parser-output">
          <p id="sous_titre_h1" class="noexcerpt"><i>Cacatua galerita</i></p>
          <style>.mw-parser-output h1 #sous_titre_h1{display:block}</style>
          <p><b>Cacatua galerita</b> est une espece d'oiseau de la famille des Cacatuidae.</p>
        </div>
      HTML
      summary = service.summary_from_parsed( parsed_doc_for( html ) )
      expect( summary ).to include( "Cacatua galerita" )
      expect( summary ).not_to match( /\.mw-parser-output/ )
    end

    it "ignores banner paragraphs and returns the descriptive lead paragraph" do
      html = <<~HTML
        <div class="mw-parser-output">
          <div class="bandeau-container metadata hatnote">
            <p>Vous lisez un bon article labellise en 2008.</p>
          </div>
          <p><b>Psittaciformes</b> est un ordre d'oiseaux comprenant les perroquets.</p>
        </div>
      HTML
      summary = service.summary_from_parsed( parsed_doc_for( html ) )
      expect( summary ).to include( "Psittaciformes" )
      expect( summary ).not_to include( "bon article" )
    end
  end
end
