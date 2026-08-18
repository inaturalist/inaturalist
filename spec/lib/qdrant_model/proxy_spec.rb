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

    describe "enabled?" do
      it "returns true if a client is configured" do
        expect( TaxonPhoto.__qdrant__.enabled? ).to be true
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

    describe "disabled" do
      let( :vector_size ) { 2048 }
      let( :embedding ) { Array.new( vector_size ) { rand } }

      before do
        allow( TaxonPhoto.__qdrant__ ).to receive( :client ).and_return( nil )
      end

      before do | example |
        next if example.metadata[:skip_spec_overrides]

        # mock the remote fetching of taxon photo embeddings, and return the test embedding
        allow( TaxonPhoto ).to receive( :embeddings_for_taxon_photos ) do | taxon_photos |
          taxon_photos.to_h {| tp | [tp.id.to_s, embedding] }
        end
        # enable all lifecycle callbacks for TaxonPhoto for: :create, :update, and :destroy
        allow( TaxonPhoto ).to receive( :qdrant_lifecycle_callback_enabled ) do | action |
          [:create, :update, :destroy].include?( action )
        end
      end

      let( :taxon_photo ) { TaxonPhoto.make! }

      describe "enabled?" do
        it "returns false if a client is not configured" do
          expect( TaxonPhoto.__qdrant__.enabled? ).to be false
        end
      end

      describe "set_configuration" do
        it "still allows the configuration to be set when disabled" do
          # the collection definitions will still exist and will still be loaded even if Qdrant
          # is not enabled. Allow the configuration to be set, but all other methods like
          # those that actually create the collection, will be disabled
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
        it "returns false when disabled" do
          expect( TaxonPhoto.__qdrant__.collection_exists? ).to be false
        end
      end

      describe "create_collection!" do
        it "returns nil when disabled" do
          expect( TaxonPhoto.__qdrant__.create_collection! ).to be_nil
        end
      end

      describe "delete_collection!" do
        it "returns nil when disabled" do
          expect( TaxonPhoto.__qdrant__.delete_collection! ).to be_nil
        end
      end

      describe "upsert_points" do
        it "returns nil when disabled" do
          expect( TaxonPhoto.__qdrant__.upsert_points( [taxon_photo.as_qdrant_json] ) ).to be_nil
          expect( TaxonPhoto.__qdrant__.count ).to eq 0
        end
      end

      describe "count" do
        it "returns zero when disabled" do
          expect( TaxonPhoto.__qdrant__.count ).to eq 0
        end
      end

      describe "get" do
        it "returns nil when disabled" do
          expect( TaxonPhoto.__qdrant__.get( taxon_photo.id ) ).to be_nil
        end
      end

      describe "get_all" do
        it "returns an empty array when disabled" do
          expect( TaxonPhoto.__qdrant__.get_all( [taxon_photo.id] ) ).to eq []
        end
      end

      describe "delete" do
        it "returns nil when disabled" do
          expect( TaxonPhoto.__qdrant__.delete( [taxon_photo.id] ) ).to be_nil
        end
      end
    end
  end
end
