require "spec_helper"

describe "Taxon Index" do
  it "as_indexed_json should return a hash" do
    t = Taxon.make!
    json = t.as_indexed_json
    expect( json ).to be_a Hash
  end

  describe "prepare_batch_for_index" do
    it "caches project_ids" do
      t = Taxon.make!
      lt = ListedTaxon.make!(taxon: t, list: CheckList.make!, place: make_place_with_geom)
      expect(t.indexed_place_ids).to eq nil
      Taxon.prepare_batch_for_index([ t ])
      expect(t.indexed_place_ids).to eq [ lt.place_id ]
    end

    it "sets project_ids to an empty array by default" do
      t = Taxon.make!
      expect(t.indexed_place_ids).to eq nil
      Taxon.prepare_batch_for_index([ t ])
      expect(t.indexed_place_ids).to eq [ ]
    end
  end
end
