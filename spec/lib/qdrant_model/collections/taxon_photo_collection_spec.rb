# frozen_string_literal: true

require "spec_helper"

describe "TaxonPhoto Collection" do
  let( :embedding ) { Array.new( 2048 ) { rand } }
  let( :taxon_photo_id ) { 100 }
  qdrant_models( TaxonPhoto )

  it "as_qdrant_json returns a hash" do
    allow( TaxonPhoto ).to receive( :embeddings_for_taxon_photos ) do
      { taxon_photo_id.to_s => embedding }
    end
    tp = TaxonPhoto.make!( id: taxon_photo_id )
    json = tp.as_qdrant_json
    expect( json[:id] ).to eq taxon_photo_id
    expect( json[:vector] ).to eq embedding
    expect( json[:payload][:id] ).to eq taxon_photo_id
    expect( json[:payload][:taxon_id] ).to eq tp.taxon_id
    expect( json[:payload][:photo_id] ).to eq tp.photo_id
    expect( json[:payload][:photo_file_updated_at] ).to eq tp.photo.file_updated_at
    expect( json[:payload][:ancestor_ids] ).to eq tp.taxon.self_and_ancestor_ids
  end

  it "as_qdrant_json does not need to regenerate embedding if nothing has changed" do
    allow( TaxonPhoto ).to receive( :embeddings_for_taxon_photos ) do
      { taxon_photo_id.to_s => embedding }
    end.once
    expect( TaxonPhoto.qdrant_count ).to eq 0
    tp = TaxonPhoto.make!( id: taxon_photo_id )
    tp.qdrant_index!
    expect( TaxonPhoto.qdrant_count ).to eq 1
    tp.qdrant_index!
    tp.qdrant_index!
  end

  it "as_qdrant_json does need to regenerate embedding if the photo has been updated" do
    allow( TaxonPhoto ).to receive( :embeddings_for_taxon_photos ) do
      { taxon_photo_id.to_s => embedding }
    end.twice
    tp = TaxonPhoto.make!( id: taxon_photo_id )
    tp.qdrant_index!
    tp.qdrant_index!
    tp.qdrant_index!
    tp.photo.touch
    tp.qdrant_index!
    tp.qdrant_index!
    tp.qdrant_index!
  end

  it "as_qdrant_json does need to regenerate embedding if the photo has changed" do
    allow( TaxonPhoto ).to receive( :embeddings_for_taxon_photos ) do
      { taxon_photo_id.to_s => embedding }
    end.twice
    tp = TaxonPhoto.make!( id: taxon_photo_id )
    tp.qdrant_index!
    tp.qdrant_index!
    tp.qdrant_index!
    tp.photo = Photo.make!
    tp.qdrant_index!
    tp.qdrant_index!
    tp.qdrant_index!
  end

  it "as_qdrant_json does need to regenerate embedding if the taxon ancestry has changed" do
    allow( TaxonPhoto ).to receive( :embeddings_for_taxon_photos ) do
      { taxon_photo_id.to_s => embedding }
    end.twice
    tp = TaxonPhoto.make!( id: taxon_photo_id )
    tp.qdrant_index!
    tp.qdrant_index!
    tp.qdrant_index!
    tp.taxon.update( parent: Taxon.make! )
    tp.qdrant_index!
    tp.qdrant_index!
    tp.qdrant_index!
  end

  it "does not index taxon photos on inactive taxa" do
    expect( TaxonPhoto ).not_to receive( :embeddings_for_taxon_photos )
    taxon = Taxon.make!( is_active: false )
    taxon_photo = TaxonPhoto.make!( taxon: taxon )
    expect( TaxonPhoto.prune_batch_for_qdrant_index( [taxon_photo] ) ).to be_empty
    expect( TaxonPhoto.qdrant_count ).to eq 0
    taxon_photo.qdrant_index!
    expect( TaxonPhoto.qdrant_count ).to eq 0
  end

  describe "prune_batch_for_qdrant_index" do
    before do
      allow( TaxonPhoto ).to receive( :embeddings_for_taxon_photos ) do | taxon_photos |
        taxon_photos.to_h {| tp | [tp.id.to_s, embedding] }
      end
    end

    it "returns the entire batch if none of the instances are indexed" do
      batch = [TaxonPhoto.make!]
      expect( TaxonPhoto.prune_batch_for_qdrant_index( batch ) ).to eq batch
    end

    it "prunes indexed instances when no attributes have been changed" do
      batch = [TaxonPhoto.make!]
      TaxonPhoto.qdrant_index!( ids: batch.map( &:id ) )
      expect( TaxonPhoto.prune_batch_for_qdrant_index( batch ) ).to be_empty
    end

    it "does not prune instances when the taxon ancestry has changed" do
      batch = [TaxonPhoto.make!]
      TaxonPhoto.qdrant_index!( ids: batch.map( &:id ) )
      batch[0].taxon.update( parent: Taxon.make! )
      expect( TaxonPhoto.prune_batch_for_qdrant_index( batch ) ).to eq batch
    end

    it "does not prune instances when the photo_id has changed" do
      batch = [TaxonPhoto.make!]
      TaxonPhoto.qdrant_index!( ids: batch.map( &:id ) )
      batch[0].update( photo: Photo.make! )
      expect( TaxonPhoto.prune_batch_for_qdrant_index( batch ) ).to eq batch
    end

    it "does not prune instances when photo_file_updated_at goes from nil to populated" do
      batch = [TaxonPhoto.make!]
      expect( batch[0].photo.file_updated_at ).to be_nil
      TaxonPhoto.qdrant_index!( ids: batch.map( &:id ) )
      batch[0].photo.update( file_updated_at: Time.now )
      expect( TaxonPhoto.prune_batch_for_qdrant_index( batch ) ).to eq batch
    end

    it "does not prune instances when photo_file_updated_at goes from populated to nil" do
      batch = [TaxonPhoto.make!( photo: Photo.make!( file_updated_at: 10.minutes.ago ) )]
      expect( batch[0].photo.file_updated_at ).not_to be_nil
      TaxonPhoto.qdrant_index!( ids: batch.map( &:id ) )
      batch[0].photo.update( file_updated_at: nil )
      expect( batch[0].photo.file_updated_at ).to be_nil
      expect( TaxonPhoto.prune_batch_for_qdrant_index( batch ) ).to eq batch
    end

    it "does not prune instances when photo_file_updated_at changes" do
      batch = [TaxonPhoto.make!( photo: Photo.make!( file_updated_at: 10.minutes.ago ) )]
      expect( batch[0].photo.file_updated_at ).not_to be_nil
      TaxonPhoto.qdrant_index!( ids: batch.map( &:id ) )
      batch[0].photo.update( file_updated_at: Time.now )
      expect( batch[0].photo.file_updated_at ).not_to be_nil
      expect( TaxonPhoto.prune_batch_for_qdrant_index( batch ) ).to eq batch
    end
  end
end
