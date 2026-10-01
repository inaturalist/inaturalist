# frozen_string_literal: true

require "spec_helper"

describe TaxonPhoto do
  it { is_expected.to belong_to :taxon }
  it { is_expected.to belong_to :photo }

  elastic_models( Observation )
  describe "creation" do
    it "should be invalid if there are already the maximum amount of taxon photos" do
      t = Taxon.make!
      TaxonPhoto::MAX_TAXON_PHOTOS.times do
        TaxonPhoto.make!( taxon: t )
      end
      tp = TaxonPhoto.make( taxon: t )
      expect( tp ).not_to be_valid
    end
  end
  describe "destruction" do
    it "should unfeature the taxon if this was the last photo" do
      tp = TaxonPhoto.make!
      t = tp.taxon
      t.update( featured_at: Time.now )
      t.reload
      expect( t.featured_at ).not_to be_blank
      t.photos = []
      t.reload
      expect( t.featured_at ).to be_blank
    end
  end

  it "flagged taxon photos are removed" do
    taxon_photo = TaxonPhoto.make!
    expect( TaxonPhoto.where( id: taxon_photo.id ).first ).not_to be_nil
    Flag.make!( flaggable: taxon_photo.photo )
    expect( TaxonPhoto.where( id: taxon_photo.id ).first ).to be_nil
  end

  it "cannot be created from flagged photos" do
    photo = Photo.make!
    Flag.make!( flaggable: photo )
    taxon_photo = TaxonPhoto.make( photo: photo )
    expect( taxon_photo ).not_to be_valid
    expect( taxon_photo.errors[:photo] ).not_to be_empty
  end

  describe "as_indexed_json" do
    it "returns a hash of metadata" do
      tp = TaxonPhoto.make!
      json = tp.as_indexed_json
      expect( json[:taxon_id] ).to eq tp.taxon_id
      expect( json[:photo][:id] ).to eq tp.photo_id
      expect( json[:photo][:license_code] ).to eq tp.photo.index_license_code
      expect( json[:photo][:attribution] ).to eq tp.photo.attribution
      expect( json[:photo][:url] ).to eq tp.photo.square_url
      expect( json[:photo][:original_dimensions] ).to eq tp.photo.original_dimensions
      expect( json[:photo][:flags] ).to eq []
      expect( json[:photo][:native_page_url] ).to eq nil
      expect( json[:photo][:native_photo_id] ).to eq nil
      expect( json[:photo][:type] ).to eq nil
      expect( json[:photo]["square_url"] ).to eq tp.photo.best_url( :square )
      expect( json[:photo]["small_url"] ).to eq tp.photo.best_url( :small )
      expect( json[:photo]["medium_url"] ).to eq tp.photo.best_url( :medium )
      expect( json[:photo]["large_url"] ).to eq tp.photo.best_url( :large )
      expect( json[:photo]["original_url"] ).to eq tp.photo.best_url( :original )
    end
  end

  describe "qdrant_reindex_by_ids" do
    let( :embedding ) { Array.new( 2048 ) { rand } }
    qdrant_models( TaxonPhoto )

    before do
      allow( TaxonPhoto ).to receive( :embeddings_for_taxon_photos ) do | taxon_photos |
        taxon_photos.to_h {| tp | [tp.id.to_s, embedding] }
      end
    end

    it "does nothing when given blank ids" do
      expect( TaxonPhoto ).not_to receive( :qdrant_delete_by_ids! )
      expect( TaxonPhoto ).not_to receive( :qdrant_index! )
      TaxonPhoto.qdrant_reindex_by_ids( nil )
      TaxonPhoto.qdrant_reindex_by_ids( [] )
    end

    it "does nothing when not given an array" do
      taxon_photo = TaxonPhoto.make!
      expect( TaxonPhoto ).not_to receive( :qdrant_delete_by_ids! )
      expect( TaxonPhoto ).not_to receive( :qdrant_index! )
      TaxonPhoto.qdrant_reindex_by_ids( taxon_photo.id )
      TaxonPhoto.qdrant_reindex_by_ids( taxon_photo.id.to_s )
    end

    it "removes points for photos of inactive taxa without touching other points" do
      deactivated_taxon_photo = TaxonPhoto.make!( taxon: Taxon.make! )
      other_taxon_photo = TaxonPhoto.make!( taxon: Taxon.make! )
      TaxonPhoto.qdrant_index!( ids: [deactivated_taxon_photo.id, other_taxon_photo.id] )
      expect( TaxonPhoto.qdrant_count ).to eq 2

      # update_column skips Taxon callbacks, so no reindexing job is queued and
      # this example only exercises qdrant_reindex_by_ids
      deactivated_taxon_photo.taxon.update_column( :is_active, false )
      expect( TaxonPhoto ).not_to receive( :embeddings_for_taxon_photos )
      TaxonPhoto.qdrant_reindex_by_ids( [deactivated_taxon_photo.id] )

      expect( TaxonPhoto.qdrant_get( deactivated_taxon_photo.id ) ).to be_nil
      expect( TaxonPhoto.qdrant_get( other_taxon_photo.id ) ).not_to be_nil
      expect( TaxonPhoto.qdrant_count ).to eq 1
    end

    it "indexes photos of active taxa that are not yet indexed" do
      taxon = Taxon.make!( is_active: false )
      taxon_photo = TaxonPhoto.make!( taxon: taxon )
      taxon.update_column( :is_active, true )
      expect( TaxonPhoto.qdrant_count ).to eq 0

      TaxonPhoto.qdrant_reindex_by_ids( [taxon_photo.id] )

      point = TaxonPhoto.qdrant_get( taxon_photo.id )
      expect( point ).not_to be_nil
      expect( point["payload"]["taxon_id"] ).to eq taxon.id
      expect( point["payload"]["ancestor_ids"] ).to match_array( taxon.reload.self_and_ancestor_ids )
    end

    it "deletes existing points before reindexing them" do
      taxon_photo = TaxonPhoto.make!
      TaxonPhoto.qdrant_index!( ids: [taxon_photo.id] )
      expect( TaxonPhoto.qdrant_count ).to eq 1

      expect( TaxonPhoto ).to receive( :qdrant_delete_by_ids! ).ordered.and_call_original
      expect( TaxonPhoto ).to receive( :qdrant_index! ).ordered.and_call_original
      # the delete means pruning no longer sees an existing point, so the
      # embedding is regenerated
      expect( TaxonPhoto ).to receive( :embeddings_for_taxon_photos ).once.
        and_return( { taxon_photo.id.to_s => embedding } )
      TaxonPhoto.qdrant_reindex_by_ids( [taxon_photo.id] )

      expect( TaxonPhoto.qdrant_get( taxon_photo.id ) ).not_to be_nil
      expect( TaxonPhoto.qdrant_count ).to eq 1
    end

    it "raises when Qdrant cannot be reached so the delayed job is retried" do
      taxon_photo = TaxonPhoto.make!
      allow( TaxonPhoto.__qdrant__.client.points ).to receive( :delete ).
        and_raise( Faraday::ConnectionFailed )
      expect do
        TaxonPhoto.qdrant_reindex_by_ids( [taxon_photo.id] )
      end.to raise_error( Faraday::ConnectionFailed )
    end
  end
end
