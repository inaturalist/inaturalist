require File.dirname(__FILE__) + '/../spec_helper.rb'

describe TaxonFramework do
  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to :source }
  it { is_expected.to belong_to(:taxon).inverse_of :taxon_framework }
  it { is_expected.to have_many(:taxon_framework_relationships).dependent :destroy }
  it { is_expected.to have_many(:taxon_curators).inverse_of(:taxon_framework).dependent :destroy }

  it { is_expected.to validate_presence_of :taxon_id }

  describe "complete" do
    it "should destroy TaxonCurators when set to false" do
      t = Taxon.make!
      tf = TaxonFramework.make!( taxon: t, rank_level: Taxon::RANK_LEVELS[Taxon::SUBSPECIES] )
      tc = TaxonCurator.make!( taxon_framework: tf )
      tf.update( rank_level: nil )
      expect( TaxonCurator.find_by_id( tc.id ) ).to be_nil
    end

    describe "rank_level" do
      it "should reindex all descendants when changed" do
        superfamily = Taxon.make!( rank: Taxon::SUPERFAMILY )
        taxon_framework = TaxonFramework.make!( taxon: superfamily, rank_level: Taxon::RANK_LEVELS[Taxon::SPECIES] )
        family = Taxon.make!( rank: Taxon::FAMILY, parent: superfamily )
        genus = Taxon.make!( rank: Taxon::GENUS, parent: family )
        species = Taxon.make!( rank: Taxon::SPECIES, parent: genus )
        without_delay { taxon_framework.update!( complete: true ) }
        Delayed::Worker.new.work_off
        es_genus = Taxon.elastic_search( where: { id: genus.id } ).results.results.first
        es_family = Taxon.elastic_search( where: { id: family.id } ).results.results.first
        expect( es_genus.complete_species_count ).to eq 1
        without_delay { taxon_framework.update!( rank_level: Taxon::RANK_LEVELS[Taxon::GENUS] ) }
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

  describe "get_flagged_taxa" do
    let( :family ) { Taxon.make!( rank: Taxon::FAMILY ) }
    let( :taxon_framework ) { TaxonFramework.make!( taxon: family, rank_level: Taxon::RANK_LEVELS[Taxon::SPECIES] ) }
    let( :genus ) { Taxon.make!( rank: Taxon::GENUS, parent: family ) }
    let( :other_genus ) { Taxon.make!( rank: Taxon::GENUS, parent: family ) }
    let( :species ) { Taxon.make!( rank: Taxon::SPECIES, parent: genus ) }

    it "should return each flagged taxon once with its open flag count" do
      2.times { Flag.make!( flaggable: genus ) }
      flagged_taxa = taxon_framework.get_flagged_taxa
      expect( flagged_taxa.map( &:id ) ).to eq [genus.id]
      expect( flagged_taxa.first.open_flags_count ).to eq 2
    end

    it "should not include resolved flags" do
      Flag.make!( flaggable: genus )
      Flag.make!( flaggable: genus, resolved: true, resolver: make_curator )
      Flag.make!( flaggable: other_genus, resolved: true, resolver: make_curator )
      flagged_taxa = taxon_framework.get_flagged_taxa
      expect( flagged_taxa.map( &:id ) ).to eq [genus.id]
      expect( flagged_taxa.first.open_flags_count ).to eq 1
    end

    it "should order taxa by open flag count" do
      Flag.make!( flaggable: genus )
      3.times { Flag.make!( flaggable: species ) }
      expect( taxon_framework.get_flagged_taxa.map( &:id ) ).to eq [species.id, genus.id]
    end

    it "should limit results to FLAGGED_TAXA_LIMIT" do
      stub_const( "TaxonFramework::FLAGGED_TAXA_LIMIT", 1 )
      Flag.make!( flaggable: genus )
      Flag.make!( flaggable: other_genus )
      expect( taxon_framework.get_flagged_taxa.length ).to eq 1
    end

    it "should only include taxa in the subtree of the taxon option" do
      Flag.make!( flaggable: species )
      Flag.make!( flaggable: other_genus )
      expect( taxon_framework.get_flagged_taxa( taxon: genus ).map( &:id ) ).to eq [species.id]
    end
  end
end
