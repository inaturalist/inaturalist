require "spec_helper"

describe "TaxonDescribers" do
  describe "Wikipedia" do

    before(:all) do
      @animalia = Taxon.make!(name: "Animalia")
      @wikipedia_response = OpenStruct.new(body: "<rsp>OK</rsp>")
    end

    it "creates the endpoint" do
      expect(ApiEndpoint.count).to eq 0
      expect(Net::HTTP).to receive(:start).and_return(@wikipedia_response)
      TaxonDescribers::Wikipedia.new.describe(@animalia)
      expect(ApiEndpoint.count).to eq 1
      endpoint = ApiEndpoint.first
      expect(endpoint.title).to eq "Wikipedia (EN)"
      expect(endpoint.description).to eq nil
      expect(endpoint.documentation_url).to eq "http://en.wikipedia.org/w/api.php"
      expect(endpoint.base_url).to eq "http://en.wikipedia.org/w/api.php?"
      expect(endpoint.cache_hours).to eq 720
    end

    it "creates the endpoint based on locale" do
      I18n.locale = "fr"
      expect(Net::HTTP).to receive(:start).and_return(@wikipedia_response)
      TaxonDescribers::Wikipedia.new.describe(@animalia)
      expect(ApiEndpoint.first.title).to eq "Wikipedia (FR)"
      I18n.locale = "en"
    end

    it "caches the result" do
      expect(ApiEndpointCache.count).to eq 0
      expect(Net::HTTP).to receive(:start).and_return(@wikipedia_response)
      TaxonDescribers::Wikipedia.new.describe(@animalia)
      expect(ApiEndpointCache.count).to eq 1
      cache = ApiEndpointCache.first
      expect(cache.request_url).to eq(
        "http://en.wikipedia.org/w/api.php?page=Animalia&redirects=true&action=parse&format=xml")
      expect(cache.response).to eq @wikipedia_response.body
      expect(cache.cached?).to be true
    end

    it "caches the result based on locale" do
      I18n.locale = "fr"
      expect(Net::HTTP).to receive(:start).and_return(@wikipedia_response)
      TaxonDescribers::Wikipedia.new.describe(@animalia)
      expect(ApiEndpointCache.first.request_url).to eq(
        "http://fr.wikipedia.org/w/api.php?page=Animalia&redirects=true&action=parse&format=xml")
      I18n.locale = "en"
    end

  end
end
