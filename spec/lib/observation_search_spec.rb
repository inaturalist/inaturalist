require "spec_helper"

describe Observation do
  describe "elastic_taxon_leaf_ids" do
    before(:each) do
      enable_elastic_indexing( Observation )
      Taxon.destroy_all
      @family = Taxon.make!(name: "Hominidae", rank: "family")
      @genus = Taxon.make!(name: "Homo", rank: "genus", parent: @family)
      @sapiens = Taxon.make!(name: "Homo sapiens", rank: "species", parent: @genus)
      @habilis = Taxon.make!(name: "Homo habilis", rank: "species", parent: @genus)
      AncestryDenormalizer.truncate
      AncestryDenormalizer.denormalize
    end
    after(:each) { disable_elastic_indexing( Observation ) }

    it "returns the leaf taxon id" do
      2.times{ Observation.make!(taxon: @family) }
      expect( Observation.elastic_taxon_leaf_ids.size ).to eq 1
      expect( Observation.elastic_taxon_leaf_ids[0] ).to eq @family.id
      2.times{ Observation.make!(taxon: @genus) }
      expect( Observation.elastic_taxon_leaf_ids.size ).to eq 1
      expect( Observation.elastic_taxon_leaf_ids[0] ).to eq @genus.id
      2.times{ Observation.make!(taxon: @sapiens) }
      expect( Observation.elastic_taxon_leaf_ids.size ).to eq 1
      expect( Observation.elastic_taxon_leaf_ids[0] ).to eq @sapiens.id
      2.times{ Observation.make!(taxon: @habilis) }
      expect( Observation.elastic_taxon_leaf_ids.size ).to eq 2
      expect( Observation.elastic_taxon_leaf_ids[0] ).to eq @sapiens.id
      expect( Observation.elastic_taxon_leaf_ids[1] ).to eq @habilis.id
    end
  end
end
