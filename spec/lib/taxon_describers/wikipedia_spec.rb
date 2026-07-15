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
      expect(endpoint.cache_hours).to eq 720
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
      # expect( cache.cached? ).to be true
      expect( cache ).to be_cached
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

    describe "content_state" do
      def stub_fetch( code:, body: )
        response = double( "Net::HTTPResponse", code: code.to_s, body: body )
        allow( MetaService ).to receive( :fetch_with_redirects ).and_return( response )
      end

      it "is :article when article content is retrieved" do
        stub_fetch( code: 200,
          body: "<parse title='Animalia' pageid='1'><text>Animals are a kingdom.</text></parse>" )
        wikipedia.describe( animalia )
        expect( wikipedia.content_state ).to eq :article
      end

      it "is :absent when Wikipedia responds without article content" do
        stub_fetch( code: 200, body: "<parse></parse>" )
        wikipedia.describe( animalia )
        expect( wikipedia.content_state ).to eq :absent
      end

      it "is :unknown when the request is throttled with nothing usable cached" do
        stub_fetch( code: 429, body: "You are making too many requests." )
        wikipedia.describe( animalia )
        expect( wikipedia.content_state ).to eq :unknown
      end
    end
  end
end
