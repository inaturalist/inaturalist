# frozen_string_literal: true

require "spec_helper"

# This spec uses TaxonPhoto, which implements `acts_as_qdrant`, as the basis for most
# specs. TaxonPhoto normally enables only the :destroy lifecycle callback because scheduled
# tasks handle indexing. These specs temporarily enable the :create and :update callbacks as well.

describe ActsAsQdrantModel do
  let( :vector_size ) { 2048 }
  let( :embedding ) { Array.new( vector_size ) { rand } }
  qdrant_models( TaxonPhoto )

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

  describe "base extensions" do
    describe "skip_qdrant_indexing" do
      it "adds an instance attribute" do
        # TaxonPhoto implements `acts_as_qdrant` and Taxon does not
        expect( TaxonPhoto.make! ).to respond_to( :skip_qdrant_indexing )
        expect( Taxon.make! ).not_to respond_to( :skip_qdrant_indexing )
      end
    end

    describe "callbacks" do
      before do
        allow( TaxonPhoto ).to receive( :qdrant_lifecycle_callback_enabled ).and_return( true )
      end

      def expect_point_matches_json( point, as_qdrant_json )
        # compare the point record from Qdrant with the as_qdrant_json from an instance,
        # ignoring their vectors. Qdrant will normalize vector values on creation making
        # it not possible to compare the result with the original
        expect( point.without( "vector" ) ).to eq( as_qdrant_json.as_json.without( "vector" ) )
        expect( point["vector"].length ).to eq( vector_size )
        expect( as_qdrant_json[:vector].length ).to eq( vector_size )
      end

      it "properly indexes the document on create" do
        expect( TaxonPhoto.qdrant_count ).to eq( 0 )
        tp = TaxonPhoto.make!
        expect( TaxonPhoto.qdrant_count ).to eq( 1 )
        point = TaxonPhoto.qdrant_get( tp.id )
        expect_point_matches_json( point, tp.as_qdrant_json )
      end

      it "properly removes the document on destroy" do
        expect( TaxonPhoto.qdrant_count ).to eq( 0 )
        tp = TaxonPhoto.make!
        expect( TaxonPhoto.qdrant_count ).to eq( 1 )
        point = TaxonPhoto.qdrant_get( tp.id )
        expect_point_matches_json( point, tp.as_qdrant_json )
        tp.destroy
        expect( TaxonPhoto.qdrant_count ).to eq( 0 )
      end

      it "properly updates the document on update" do
        expect( TaxonPhoto.qdrant_count ).to eq( 0 )
        tp = TaxonPhoto.make!
        expect( TaxonPhoto.qdrant_count ).to eq( 1 )
        original_qdrant_json = tp.as_qdrant_json
        point = TaxonPhoto.qdrant_get( tp.id )
        expect_point_matches_json( point, original_qdrant_json )

        original_photo_id = tp.photo_id
        tp.update( photo: Photo.make! )
        expect( TaxonPhoto.qdrant_count ).to eq( 1 )
        updated_qdrant_json = tp.as_qdrant_json
        point = TaxonPhoto.qdrant_get( tp.id )
        expect_point_matches_json( point, updated_qdrant_json )
        expect( updated_qdrant_json[:payload][:photo_id] ).not_to eq( original_photo_id )
      end
    end
  end

  describe "SingletonMethods" do
    it "defines a method to fetch the class proxy" do
      expect( TaxonPhoto.__qdrant__ ).to be_a( ActsAsQdrantModel::ClassMethodsProxy )
      expect( Taxon ).not_to respond_to( :__qdrant__ )
    end

    it "knows which lifecycle callbacks are enabled", skip_spec_overrides: true do
      # this is the only action TaxonPhoto actually implements. We need to skip the override
      # defined in these specs to truly test this method. Without the override, TaxonPhoto
      # would also respond true for :create and :update elsewhere in this spec
      [:destroy].each do | action |
        expect( TaxonPhoto.qdrant_lifecycle_callback_enabled( action ) ).to be true
      end
      # these lifecycle callbacks are not defined
      [:create, :update, :save, :initialize, :nonsense].each do | action |
        expect( TaxonPhoto.qdrant_lifecycle_callback_enabled( action ) ).to be false
      end
    end

    describe "qdrant_count" do
      it "returns a count of all points in the collection" do
        expect( TaxonPhoto.qdrant_count ).to eq 0
        5.times { TaxonPhoto.make! }
        expect( TaxonPhoto.qdrant_count ).to eq 5
      end
    end

    describe "qdrant_get" do
      it "returns a single point" do
        taxon_photo = TaxonPhoto.make!( photo: Photo.make!( file_updated_at: Time.now ) )
        get_response = TaxonPhoto.qdrant_get( taxon_photo.id )
        expect( get_response ).to be_a( Hash )
        expect( get_response["id"] ).to eq taxon_photo.id
        expect( get_response["vector"] ).to be_a( Array )
        expect( get_response["vector"].length ).to eq vector_size
        expect( get_response["payload"]["id"] ).to eq taxon_photo.id
        expect( get_response["payload"]["taxon_id"] ).to eq taxon_photo.taxon_id
        expect( get_response["payload"]["photo_id"] ).to eq taxon_photo.photo_id
        expect( get_response["payload"]["photo_file_updated_at"] ).to eq taxon_photo.photo.file_updated_at.to_s
        expect( get_response["payload"]["ancestor_ids"] ).to eq taxon_photo.taxon.self_and_ancestor_ids

        taxon_photo.destroy
        get_response = TaxonPhoto.qdrant_get( taxon_photo.id )
        expect( get_response ).to be_nil
      end
    end

    describe "qdrant_get_all" do
      it "returns an array of points" do
        taxon_photo = TaxonPhoto.make!( photo: Photo.make!( file_updated_at: Time.now ) )
        get_all_response = TaxonPhoto.qdrant_get_all( [taxon_photo.id] )
        expect( get_all_response ).to be_a( Array )
        expect( get_all_response.length ).to eq 1

        point = get_all_response[0]
        expect( point ).to be_a( Hash )
        expect( point["id"] ).to eq taxon_photo.id
        # vector is not returned by get_all
        expect( point ).not_to have_key( "vector" )
        expect( point["payload"]["id"] ).to eq taxon_photo.id
        expect( point["payload"]["taxon_id"] ).to eq taxon_photo.taxon_id
        expect( point["payload"]["photo_id"] ).to eq taxon_photo.photo_id
        expect( point["payload"]["photo_file_updated_at"] ).to eq taxon_photo.photo.file_updated_at.to_s
        expect( point["payload"]["ancestor_ids"] ).to eq taxon_photo.taxon.self_and_ancestor_ids
      end
    end

    describe "qdrant_delete_by_ids!" do
      it "deletes all documents with ids in the provided array" do
        taxon_photo = TaxonPhoto.make!
        expect( TaxonPhoto.qdrant_count ).to eq 1
        TaxonPhoto.qdrant_delete_by_ids!( [taxon_photo.id] )
        expect( TaxonPhoto.qdrant_count ).to eq 0
        # the DB record still exists, but the Qdrant point has been deleted
        expect( TaxonPhoto.find( taxon_photo.id ) ).to be_a( TaxonPhoto )
      end
    end

    describe "qdrant_index!" do
      before do
        # create instances and remove them from Qdrant to set up testing indexing
        10.times { TaxonPhoto.make! }
        expect( TaxonPhoto.qdrant_count ).to eq 10
        TaxonPhoto.qdrant_delete_by_ids!( TaxonPhoto.all.pluck( :id ) )
        expect( TaxonPhoto.qdrant_count ).to eq 0
      end

      it "indexes all documents by default" do
        expect( TaxonPhoto.qdrant_count ).to eq 0
        TaxonPhoto.qdrant_index!
        expect( TaxonPhoto.qdrant_count ).to eq 10
      end

      it "indexes documents by ids" do
        expect( TaxonPhoto.qdrant_count ).to eq 0
        TaxonPhoto.qdrant_index!( ids: TaxonPhoto.first( 5 ).pluck( :id ) )
        expect( TaxonPhoto.qdrant_count ).to eq 5
      end

      it "can delay indexing" do
        Delayed::Job.delete_all
        expect( Delayed::Job.count ).to eq 0
        expect( TaxonPhoto.qdrant_count ).to eq 0

        TaxonPhoto.qdrant_index!( delay: true )
        expect( Delayed::Job.count ).to eq 1
        expect( TaxonPhoto.qdrant_count ).to eq 0

        Delayed::Worker.new.work_off
        expect( Delayed::Job.count ).to eq 0
        expect( TaxonPhoto.qdrant_count ).to eq 10
      end

      it "can delay indexing while filtering by ids" do
        Delayed::Job.delete_all
        expect( Delayed::Job.count ).to eq 0
        expect( TaxonPhoto.qdrant_count ).to eq 0

        TaxonPhoto.qdrant_index!( ids: TaxonPhoto.first( 5 ).pluck( :id ), delay: true )
        expect( Delayed::Job.count ).to eq 1
        expect( TaxonPhoto.qdrant_count ).to eq 0

        Delayed::Worker.new.work_off
        expect( Delayed::Job.count ).to eq 0
        expect( TaxonPhoto.qdrant_count ).to eq 5
      end

      it "invokes the load_for_qdrant_index scope" do
        expect( TaxonPhoto ).to receive( :load_for_qdrant_index ).and_call_original
        TaxonPhoto.qdrant_index!
      end
    end
  end

  describe "InstanceMethods" do
    it "defines a method to fetch the instance proxy" do
      expect( TaxonPhoto.make!.__qdrant__ ).to be_a( ActsAsQdrantModel::InstanceMethodsProxy )
      expect( Taxon.make! ).not_to respond_to( :__qdrant__ )
    end

    describe "qdrant_index!" do
      it "indexes an instance" do
        taxon_photo = TaxonPhoto.make!
        expect( TaxonPhoto.qdrant_count ).to eq 1
        # delete the doc to test re-indexing it
        taxon_photo.qdrant_delete!
        expect( TaxonPhoto.qdrant_count ).to eq 0
        taxon_photo.qdrant_index!
        expect( TaxonPhoto.qdrant_count ).to eq 1
      end
    end

    describe "qdrant_delete!" do
      it "deletes an instance" do
        taxon_photo = TaxonPhoto.make!
        expect( TaxonPhoto.qdrant_count ).to eq 1
        taxon_photo.qdrant_delete!
        expect( TaxonPhoto.qdrant_count ).to eq 0
      end
    end
  end
end
