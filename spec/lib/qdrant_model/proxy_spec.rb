# frozen_string_literal: true

require "spec_helper"

describe ActsAsQdrantModel do
  qdrant_models( TaxonPhoto )

  describe "ClassMethodsProxy" do
    it "defines a method to fetch the class proxy" do
      expect( TaxonPhoto.__qdrant__ ).to be_a( ActsAsQdrantModel::ClassMethodsProxy )
      expect( Taxon ).not_to respond_to( :__qdrant__ )
    end

    describe "initialize" do
      it "sets some readable attributes" do
        expect( TaxonPhoto.__qdrant__.target ).to eq TaxonPhoto
        expect( TaxonPhoto.__qdrant__.client ).to eq ActsAsQdrantModel.client
        expect( TaxonPhoto.__qdrant__.collection_name ).to eq "test_taxon_photos"
        expect( TaxonPhoto.__qdrant__.lifecycle_callbacks ).to eq [:destroy]
      end
    end

    describe "inspect" do
      it "returns a readable value" do
        expect( TaxonPhoto.__qdrant__.inspect ).to start_with( "[PROXY] TaxonPhoto" )
      end
    end

    describe "set_configuration" do
      it "accepts a custom configuration" do
        original_configuration = TaxonPhoto.__qdrant__.configuration
        custom_configuration = {
          collection_parameters: {
            on_disk_payload: true
          }
        }
        TaxonPhoto.__qdrant__.set_configuration( custom_configuration )
        expect( TaxonPhoto.__qdrant__.configuration ).to eq custom_configuration

        # restore the original configuration for future specs
      ensure
        TaxonPhoto.__qdrant__.set_configuration( original_configuration )
      end
    end

    describe "collection_exists?" do
      it "returns false if the collection does not exist" do
        TaxonPhoto.__qdrant__.delete_collection!
        expect( TaxonPhoto.__qdrant__.collection_exists? ).to be false
      end

      it "returns true if collection exists" do
        expect( TaxonPhoto.__qdrant__.collection_exists? ).to be true
      end
    end

    describe "create_collection!" do
      it "creates a collection if it does not exist" do
        TaxonPhoto.__qdrant__.delete_collection!
        expect( TaxonPhoto.__qdrant__.collection_exists? ).to be false
        TaxonPhoto.__qdrant__.create_collection!
        expect( TaxonPhoto.__qdrant__.collection_exists? ).to be true
      end

      it "can force delete a collection if it already exists" do
        expect( TaxonPhoto.__qdrant__ ).to receive( :delete_collection! ).and_call_original
        expect( TaxonPhoto.__qdrant__.client.collections ).to receive( :create ).and_call_original
        TaxonPhoto.__qdrant__.create_collection!( force: true )
      end

      it "creates a collection with force if it does not already exist" do
        TaxonPhoto.__qdrant__.delete_collection!
        expect( TaxonPhoto.__qdrant__.collection_exists? ).to be false
        TaxonPhoto.__qdrant__.create_collection!( force: true )
        expect( TaxonPhoto.__qdrant__.collection_exists? ).to be true
      end

      it "does not attempt to create a collection if it already exists" do
        expect( TaxonPhoto.__qdrant__ ).to receive( :collection_exists? ).and_call_original
        expect( TaxonPhoto.__qdrant__.client.collections ).not_to receive( :create )
        TaxonPhoto.__qdrant__.create_collection!
      end
    end

    describe "delete_collection!" do
      it "deletes a collection" do
        expect( TaxonPhoto.__qdrant__.collection_exists? ).to be true
        TaxonPhoto.__qdrant__.delete_collection!
        expect( TaxonPhoto.__qdrant__.collection_exists? ).to be false
      end

      it "does not complain if called more than once" do
        expect( TaxonPhoto.__qdrant__.collection_exists? ).to be true
        TaxonPhoto.__qdrant__.delete_collection!
        TaxonPhoto.__qdrant__.delete_collection!
        TaxonPhoto.__qdrant__.delete_collection!
        expect( TaxonPhoto.__qdrant__.collection_exists? ).to be false
      end
    end
  end
end
