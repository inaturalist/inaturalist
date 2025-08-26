# frozen_string_literal: true

require "spec_helper"

describe "TaxonPhoto Index" do
  let( :embedding ) { Array.new( 2048 ) { rand } }
  let( :taxon_photo_id ) { 100 }
  elastic_models( Taxon, TaxonPhoto )

  it "as_indexed_json returns a hash" do
    allow( TaxonPhoto ).to receive( :embeddings_for_taxon_photos ) do
      { taxon_photo_id.to_s => embedding }
    end
    tp = TaxonPhoto.make!( id: taxon_photo_id )
    json = tp.as_indexed_json
    expect( json[:id] ).to eq taxon_photo_id
    expect( json[:taxon_id] ).to eq tp.taxon_id
    expect( json[:photo_id] ).to eq tp.photo_id
    expect( json[:photo_file_updated_at] ).to eq tp.photo.file_updated_at
    expect( json[:ancestor_ids] ).to eq tp.taxon.self_and_ancestor_ids
    expect( json[:embedding] ).to eq embedding
  end

  it "as_indexed_json does not need to regenerate embedding if nothing has changed" do
    allow( TaxonPhoto ).to receive( :embeddings_for_taxon_photos ) do
      { taxon_photo_id.to_s => embedding }
    end.once
    expect( TaxonPhoto.elastic_search.results.size ).to eq 0
    tp = TaxonPhoto.make!( id: taxon_photo_id )
    tp.elastic_index!
    expect( TaxonPhoto.elastic_search.results.size ).to eq 1
    tp.elastic_index!
    tp.elastic_index!
  end

  it "as_indexed_json does need to regenerate embedding if the photo has been updated" do
    allow( TaxonPhoto ).to receive( :embeddings_for_taxon_photos ) do
      { taxon_photo_id.to_s => embedding }
    end.twice
    tp = TaxonPhoto.make!( id: taxon_photo_id )
    tp.elastic_index!
    tp.elastic_index!
    tp.elastic_index!
    tp.photo.touch
    tp.elastic_index!
    tp.elastic_index!
    tp.elastic_index!
  end

  it "as_indexed_json does need to regenerate embedding if the photo has changed" do
    allow( TaxonPhoto ).to receive( :embeddings_for_taxon_photos ) do
      { taxon_photo_id.to_s => embedding }
    end.twice
    tp = TaxonPhoto.make!( id: taxon_photo_id )
    tp.elastic_index!
    tp.elastic_index!
    tp.elastic_index!
    tp.photo = Photo.make!
    tp.elastic_index!
    tp.elastic_index!
    tp.elastic_index!
  end

  it "as_indexed_json does need to regenerate embedding if the taxon ancestry has changed" do
    allow( TaxonPhoto ).to receive( :embeddings_for_taxon_photos ) do
      { taxon_photo_id.to_s => embedding }
    end.twice
    tp = TaxonPhoto.make!( id: taxon_photo_id )
    tp.elastic_index!
    tp.elastic_index!
    tp.elastic_index!
    tp.taxon.update( parent: Taxon.make! )
    tp.elastic_index!
    tp.elastic_index!
    tp.elastic_index!
  end

  it "as_indexed_json a different hash when indexing through taxa" do
    allow( TaxonPhoto ).to receive( :embeddings_for_taxon_photos ) do
      { taxon_photo_id.to_s => embedding }
    end
    tp = TaxonPhoto.make!( id: taxon_photo_id )
    expect( TaxonPhoto ).not_to receive( :embeddings_for_taxon_photos )
    json = tp.as_indexed_json( for_taxon: true )
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

  it "does not index taxon photos on inactive taxa" do
    expect( TaxonPhoto ).not_to receive( :embeddings_for_taxon_photos )
    taxon = Taxon.make!( is_active: false )
    taxon_photo = TaxonPhoto.make!( taxon: taxon )
    expect( TaxonPhoto.prune_batch_for_index( [taxon_photo] ) ).to be_empty
    expect( TaxonPhoto.elastic_search.results.size ).to eq 0
    taxon_photo.elastic_index!
    expect( TaxonPhoto.elastic_search.results.size ).to eq 0
  end
end
