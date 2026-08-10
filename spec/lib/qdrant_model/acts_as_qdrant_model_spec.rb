# frozen_string_literal: true

require "spec_helper"

describe ActsAsQdrantModel do
  VECTOR_SIZE = 2048
  let( :embedding ) { Array.new( VECTOR_SIZE ) { rand } }
  let( :taxon_photo_id ) { 100 }
  qdrant_models( TaxonPhoto )

  before do
    allow( TaxonPhoto ).to receive( :embeddings_for_taxon_photos ) do
      { taxon_photo_id.to_s => embedding }
    end
  end

  describe "callbacks" do
    before do
      # enabling all lifecycle callbacks for TaxonPhoto: :create, :update, and :destroy
      allow( TaxonPhoto ).to receive( :qdrant_lifecycle_callback_enabled ).and_return( true )
    end

    def expect_point_matches_json( point, as_qdrant_json )
      # compare the point record from Qdrant with the as_qdrant_json from an instance,
      # ignoring their vectors. Qdrant will modify vector values according to the configured
      # quantization approach making it not possible to compare the result with the original
      expect( point.without( "vector" ) ).to eq( as_qdrant_json.as_json.without( "vector" ) )
      expect( point["vector"].length ).to eq( VECTOR_SIZE )
      expect( as_qdrant_json[:vector].length ).to eq( VECTOR_SIZE )
    end

    it "properly indexes the document on create" do
      expect( TaxonPhoto.qdrant_count ).to eq( 0 )
      tp = TaxonPhoto.make!( id: taxon_photo_id )
      expect( TaxonPhoto.qdrant_count ).to eq( 1 )
      point = TaxonPhoto.qdrant_get( tp.id )
      expect_point_matches_json( point, tp.as_qdrant_json )
    end

    it "properly removes the document on destroy" do
      expect( TaxonPhoto.qdrant_count ).to eq( 0 )
      tp = TaxonPhoto.make!( id: taxon_photo_id )
      expect( TaxonPhoto.qdrant_count ).to eq( 1 )
      point = TaxonPhoto.qdrant_get( tp.id )
      expect_point_matches_json( point, tp.as_qdrant_json )
      tp.destroy
      expect( TaxonPhoto.qdrant_count ).to eq( 0 )
    end

    it "properly updates the document on update" do
      expect( TaxonPhoto.qdrant_count ).to eq( 0 )
      tp = TaxonPhoto.make!( id: taxon_photo_id )
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
