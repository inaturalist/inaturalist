require "spec_helper"

describe "TaxonDescribers" do
  describe "Wikipedia" do

    let(:animalia) { Taxon.make!( name: "Animalia" ) }
    let(:wikipedia) { TaxonDescribers::Wikipedia.new }

    it "creates the endpoint" do
      expect(ApiEndpoint.count).to eq 0
      wikipedia.describe( animalia )
      expect(ApiEndpoint.count).to eq 1
      endpoint = ApiEndpoint.first
      expect(endpoint.title).to eq "Wikipedia (EN)"
      expect(endpoint.description).to eq nil
      expect(endpoint.documentation_url).to eq "https://en.wikipedia.org/w/api.php"
      expect(endpoint.base_url).to eq "https://en.wikipedia.org/w/api.php?"
      expect(endpoint.cache_hours).to eq 168
    end

    it "creates the endpoint based on locale" do
      I18n.with_locale :fr do
        wikipedia.describe( animalia )
        expect( ApiEndpoint.first.title ).to eq "Wikipedia (FR)"
      end
    end

    it "caches the result" do
      expect( ApiEndpointCache.count ).to eq 0
      wikipedia.describe( animalia )
      expect( ApiEndpointCache.count ).to eq 1
      cache = ApiEndpointCache.first
      expect( cache.request_url ).to eq(
        "https://en.wikipedia.org/w/api.php?page=Animalia&redirects=true&action=parse&format=xml"
      )
      expect( cache.cached? ).to be true
    end

    it "caches the result based on locale" do
      I18n.with_locale :fr do
        wikipedia.describe( animalia )
        expect( ApiEndpointCache.first.request_url ).to eq(
          "https://fr.wikipedia.org/w/api.php?page=Animalia&redirects=true&action=parse&format=xml"
        )
      end
    end

    it "strips references and errors from html" do
      html = "Beggining <sup class=\"reference\">1<\/sup> middle <strong class=\"error\">X<\/strong> end"
      expect( wikipedia.clean_html( html ) ).to eq html
      expect(
        wikipedia.clean_html( html, strip_references: true )
      ).to eq( "Beggining  middle  end" )
    end

    it "generates a page_url for a taxon" do
      t = Taxon.make!( name: "Some great name" )
      expect( wikipedia.page_url( t ) ).to eq( "https://en.wikipedia.org/wiki/Some_great_name" )
    end

  end
end
