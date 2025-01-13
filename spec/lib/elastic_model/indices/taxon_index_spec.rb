# frozen_string_literal: true

require "spec_helper"

describe "Taxon Index" do
  it "as_indexed_json should return a hash" do
    t = Taxon.make!
    json = t.as_indexed_json
    expect( json ).to be_a Hash
  end

  it "does not include flagged taxon photos" do
    taxon = Taxon.make!
    taxon_photo = TaxonPhoto.make!( taxon: taxon )
    taxon.reload
    expect( taxon.as_indexed_json[:default_photo][:id] ).to eq taxon_photo.photo.id
    expect( taxon.as_indexed_json[:taxon_photos].first[:photo][:id] ).to eq taxon_photo.photo.id

    # skip callback that would delete the TaxonPhoto after flagging,
    # simulating taxon photos flagged before that callback was created
    allow( taxon_photo.photo ).to receive( :flagged_with ).and_return( true )
    Flag.make!( flaggable: taxon_photo.photo )
    taxon.reload
    expect( taxon.taxon_photos ).not_to be_empty
    expect( taxon.as_indexed_json[:default_photo] ).to be_nil
    expect( taxon.as_indexed_json[:taxon_photos] ).to be_empty
  end

  describe "prepare_batch_for_index" do
    it "caches project_ids" do
      t = Taxon.make!
      lt = ListedTaxon.make!( taxon: t, list: CheckList.make!, place: make_place_with_geom )
      expect( t.indexed_place_ids ).to eq nil
      Taxon.prepare_batch_for_index( [t] )
      expect( t.indexed_place_ids ).to eq [lt.place_id]
    end

    it "sets project_ids to an empty array by default" do
      t = Taxon.make!
      expect( t.indexed_place_ids ).to eq nil
      Taxon.prepare_batch_for_index( [t] )
      expect( t.indexed_place_ids ).to eq []
    end
  end
end
