# frozen_string_literal: true

require "spec_helper"

describe WikipediaService do
  describe "content_state" do
    let( :service ) { WikipediaService.new }

    def stub_fetch( code:, body: )
      response = double( "Net::HTTPResponse", code: code.to_s, body: body )
      allow( MetaService ).to receive( :fetch_with_redirects ).and_return( response )
    end

    it "is :article when Wikipedia returns article content" do
      stub_fetch( code: 200,
        body: "<parse title='Animalia' pageid='1'><text>Animals are a kingdom.</text></parse>" )
      service.page_details( "Animalia" )
      expect( service.content_state ).to eq :article
    end

    it "is :absent when Wikipedia returns a response with no article content" do
      stub_fetch( code: 200, body: "<parse></parse>" )
      service.page_details( "Animalia" )
      expect( service.content_state ).to eq :absent
    end

    it "is :unknown when the request is throttled with nothing usable cached" do
      stub_fetch( code: 429, body: "You are making too many requests." )
      service.page_details( "Animalia" )
      expect( service.content_state ).to eq :unknown
    end
  end
end
