require File.dirname(__FILE__) + '/../spec_helper.rb'

describe "complete" do
  it "should destroy TaxonCurators when set to false" do
    t = Taxon.make!
    tf = TaxonFramework.make!( taxon: t, rank_level: Taxon::RANK_LEVELS[Taxon::SUBSPECIES] )
    tc = TaxonCurator.make!( taxon_framework: tf )
    tf.update_attributes( rank_level: nil )
    expect( TaxonCurator.find_by_id( tc.id ) ).to be_nil
  end
  
  describe "rank_level" do
    it "should reindex all descendants when changed" do
      superfamily = Taxon.make!( rank: Taxon::SUPERFAMILY )
      taxon_framework = TaxonFramework.make!( taxon: superfamily, rank_level: Taxon::RANK_LEVELS[Taxon::SPECIES] )
      family = Taxon.make!( rank: Taxon::FAMILY, parent: superfamily )
      genus = Taxon.make!( rank: Taxon::GENUS, parent: family )
      species = Taxon.make!( rank: Taxon::SPECIES, parent: genus )
      without_delay { taxon_framework.update_attributes!( complete: true ) }
      Delayed::Worker.new.work_off
      es_genus = Taxon.elastic_search( where: { id: genus.id } ).results.results.first
      es_family = Taxon.elastic_search( where: { id: family.id } ).results.results.first
      expect( es_genus.complete_species_count ).to eq 1
      without_delay { taxon_framework.update_attributes!( rank_level: Taxon::RANK_LEVELS[Taxon::GENUS] ) }
      genus.reload
      family.reload
      es_genus = Taxon.elastic_search( where: { id: genus.id } ).results.results.first
      es_family = Taxon.elastic_search( where: { id: family.id } ).results.results.first
      expect( es_genus.complete_species_count ).to be_nil
    end
    it "should not be above the rank of the taxon" do
      t = Taxon.make( rank: Taxon::FAMILY )
      taxon_framework = TaxonFramework.make( taxon: t, rank_level: Taxon::RANK_LEVELS[Taxon::ORDER] )
      expect( taxon_framework ).not_to be_valid
    end
  end
end