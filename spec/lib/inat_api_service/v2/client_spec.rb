# frozen_string_literal: true

require "spec_helper"

describe INatAPIService::V2::Client do
  subject { described_class.new }

  let( :body ) { "{}" }
  let( :url ) { INatAPIService::V2::Client::BASE_URL }

  before do
    stub_request( :get, /#{INatAPIService::V2::Client::BASE_URL}/ ).to_return( status: 200, body: body )
  end

  describe "#get_taxon_by_id" do
    let( :url ) { "#{super()}/taxa/123" }

    context "with no fields specified" do
      before { subject.get_taxon_by_id 123 }
      it "requests all fields" do
        expect( a_request( :get, url ).with( query: { fields: "all" } ) ).to have_been_made
      end
    end

    context "with fields specified" do
      before { subject.get_taxon_by_id 123, fields: "id,name" }
      it "requests only specified fields" do
        expect( a_request( :get, url ).with( query: { fields: "id,name" } ) ).to have_been_made
      end
    end
  end

  describe "parsing" do
    subject { described_class.new.get_taxon_by_id 123 }
    let( :url ) { "#{super()}/taxa/123" }
    let( :body ) { File.read "spec/lib/inat_api_service/stubs/get_taxon_by_id.json" }

    it { is_expected.to be_a Hash }

    it "symbolizes keys" do
      expect( subject.keys ).to all( be_a Symbol )
    end

    context "with invalid JSON" do
      let( :body ) do
        <<~JSON
          {
            "id": val,
            key: "val"
          }
        JSON
      end

      it "raises error" do
        expect { subject }.to raise_error INatAPIService::V2::Error
      end
    end
  end
end
