# frozen_string_literal: true

require "#{File.dirname( __FILE__ )}/../spec_helper.rb"

describe Taxon, "associations" do
  it { is_expected.to belong_to( :creator ).class_name "User" }
  it { is_expected.to belong_to( :iconic_taxon ).class_name( "Taxon" ).with_foreign_key "iconic_taxon_id" }
  it { is_expected.to belong_to :source }
  it { is_expected.to belong_to( :taxon_framework_relationship ).touch true }
  it { is_expected.to have_many( :assessments ).dependent :nullify }
  it { is_expected.to have_many( :conservation_statuses ).dependent :destroy }
  it { is_expected.to have_many( :controlled_term_taxa ).inverse_of( :taxon ).dependent :destroy }
  it { is_expected.to have_many( :guide_taxa ).inverse_of( :taxon ).dependent :nullify }
  it { is_expected.to have_many( :guides ).inverse_of( :taxon ).dependent :nullify }
  it { is_expected.to have_many( :identifications ).dependent :destroy }
  it { is_expected.to have_many( :listed_taxa ).dependent :destroy }
  it { is_expected.to have_many( :listed_taxon_alterations ).inverse_of( :taxon ).dependent :delete_all }
  it { is_expected.to have_many( :lists ).through :listed_taxa }
  it { is_expected.to have_many( :observations ).dependent :nullify }
  it { is_expected.to have_many( :photos ).through :taxon_photos }
  it { is_expected.to have_many( :taxon_change_taxa ).inverse_of :taxon }
  it { is_expected.to have_many( :taxon_curators ).inverse_of :taxon }
  it { is_expected.to have_many( :taxon_descriptions ).dependent :destroy }
  it { is_expected.to have_many :taxon_changes }
  it { is_expected.to have_many( :taxon_links ).dependent :delete_all }
  it { is_expected.to have_many( :taxon_names ).dependent :destroy }
  it { is_expected.to have_many( :taxon_photos ).dependent :destroy }
  it { is_expected.to have_one( :taxon_range ).dependent :destroy }
  it { is_expected.to have_many( :taxon_scheme_taxa ).dependent :destroy }
  it { is_expected.to have_many( :taxon_schemes ).through :taxon_scheme_taxa }
  it { is_expected.to have_one( :atlas ).inverse_of( :taxon ).dependent :destroy }
  it { is_expected.to have_one( :simplified_tree_milestone_taxon ).dependent :destroy }
  it { is_expected.to have_one( :taxon_framework ).inverse_of( :taxon ).dependent :destroy }
end

describe Taxon do
  elastic_models( Observation, Taxon )

  before( :all ) do
    load_test_taxa
    @taxon = @Calypte_anna
  end

  it "should have a working #grafted method" do
    expect( @taxon ).to respond_to( :grafted? )
    expect( @taxon.grafted? ).to be( true )

    ungrafted = Taxon.create(
      name: "Pseudacris crucifer", # Spring Peeper
      rank: "species"
    )
    expect( ungrafted.grafted? ).to be( false )
    expect( @Animalia.grafted? ).to be( true )
  end

  it "species_or_lower? should be false for Animalia" do
    expect( @Animalia.species_or_lower? ).to be( false )
  end

  it "species_or_lower? should be true for Pseudacris regilla" do
    expect( @Pseudacris_regilla.species_or_lower? ).to be( true )
  end

  it "has rank levels for stateofmatter and root" do
    expect( Taxon::STATEOFMATTER_LEVEL ).to eq 100
    expect( Taxon::ROOT_LEVEL ).to eq 100
    expect( Taxon::ROOT_LEVEL ).to eq Taxon::STATEOFMATTER_LEVEL
  end
end

describe Taxon, "creation" do
  elastic_models( Observation, Taxon )

  it "should set an iconic taxon if this taxon was grafted" do
    load_test_taxa
    taxon = Taxon.make!( name: "Pseudacris imaginarius", rank: Taxon::SPECIES )
    taxon.parent = @Pseudacris
    taxon.save!
    expect( taxon ).to be_grafted
    taxon.reload
    expect( taxon.iconic_taxon ).to eq @Amphibia
  end

  it "should create a taxon name with the same name after save" do
    t = Taxon.make!
    expect( t.taxon_names ).not_to be_empty
    expect( t.taxon_names.map( &:name ) ).to include( t.name )
  end

  it "should create a taxon name with the same name after save even if invalid on source_identifier" do
    source_identifier = "foo"
    source = Source.make!
    TaxonName.make!( source: source, source_identifier: source_identifier )
    t = Taxon.make!( source: source, source_identifier: source_identifier )
    expect( t.taxon_names.map( &:name ) ).to include( t.name )
  end

  it "should capitalize its name" do
    taxon = Taxon.new( name: "balderdash", rank: "genus" )
    taxon.save
    expect( taxon.name ).to eq "Balderdash"
  end

  it "should capitalize genushybrids with leading x correclty" do
    taxon = Taxon.make!( name: "× chitalpa", rank: Taxon::GENUSHYBRID )
    expect( taxon.name ).to eq "× Chitalpa"
    taxon = Taxon.make!( name: "× Chitalpa", rank: Taxon::GENUSHYBRID )
    expect( taxon.name ).to eq "× Chitalpa"
  end

  it "should capitalize Foo x Bar style genushybrids correctly" do
    taxon = Taxon.make!( name: "foo × bar", rank: Taxon::GENUSHYBRID )
    expect( taxon.name ).to eq "Foo × Bar"
    taxon = Taxon.make!( name: "Foo × Bar", rank: Taxon::GENUSHYBRID )
    expect( taxon.name ).to eq "Foo × Bar"
  end

  it "should capitalize hybrid species in genushybrids correctly" do
    taxon = Taxon.make!( name: "Foo bar × Baz roq", rank: Taxon::HYBRID )
    expect( taxon.name ).to eq "Foo bar × Baz roq"
  end

  it "should not fail on poorly-formatted hybrid names" do
    [
      "Carex × leutzii pseudofulva",
      "Calystegia sepium roseata × c tuguriorum"
    ].each do | name |
      taxon = Taxon.make!( name: name, rank: Taxon::HYBRID )
      expect( taxon ).to be_valid
    end
  end

  it "should capitalize hybrid names of the form Genus species1 x species2" do
    taxon = Taxon.make!( name: "genusone speciesone × speciestwo", rank: Taxon::HYBRID )
    expect( taxon.name ).to eq "Genusone speciesone × speciestwo"
  end

  it "should set the rank_level based on the rank" do
    t = Taxon.make!
    expect( t.rank_level ).to eq Taxon::RANK_LEVELS[t.rank]
  end

  it "should remove leading rank from the name" do
    t = Taxon.make!( name: "Gen Pseudacris" )
    expect( t.name ).to eq "Pseudacris"
  end

  it "should remove internal 'var' from name" do
    t = Taxon.make!( name: "Quercus agrifolia var. agrifolia" )
    expect( t.name ).to eq "Quercus agrifolia agrifolia"
  end

  it "should remove internal 'ssp' from name" do
    t = Taxon.make!( name: "Quercus agrifolia ssp. agrifolia" )
    expect( t.name ).to eq "Quercus agrifolia agrifolia"
  end

  it "should remove internal 'subsp' from name" do
    t = Taxon.make!( name: "Quercus agrifolia subsp. agrifolia" )
    expect( t.name ).to eq "Quercus agrifolia agrifolia"
  end

  it "should allow fo as a specific epithet" do
    name = "Mahafalytenus fo"
    t = Taxon.make!( name: name )
    expect( t.name ).to eq name
  end

  it "should strip trailing space" do
    expect( Taxon.make!( name: "Trailing space  " ).name ).to eq "Trailing space"
  end
  it "should strip leading space" do
    expect( Taxon.make!( name: "   Leading space" ).name ).to eq "Leading space"
  end

  it "should prevent creating a taxon with a rank coarser than the parent" do
    parent = Taxon.make!( rank: Taxon::GENUS )
    taxon = Taxon.new( name: "balderdash", rank: Taxon::FAMILY, parent: parent )
    taxon.save
    taxon.valid?
    expect( taxon.errors ).not_to be_blank
  end

  it "should prevent creating an active taxon with an inactive parent" do
    parent = Taxon.make!( rank: Taxon::GENUS, is_active: false )
    taxon = Taxon.new( name: "balderdash", rank: Taxon::SPECIES, parent: parent )
    taxon.save
    expect( taxon.errors ).not_to be_blank
  end

  it "should allow creating an active taxon with an inactive parent if output of draft taxon change" do
    input_taxon = Taxon.make!( rank: Taxon::GENUS, is_active: true )
    output_taxon = Taxon.make!( rank: Taxon::GENUS, is_active: false )
    swap = TaxonSwap.make
    swap.add_input_taxon( input_taxon )
    swap.add_output_taxon( output_taxon )
    swap.save!

    taxon = Taxon.new( name: "balderdash", rank: Taxon::SPECIES, parent: output_taxon )
    taxon.save
    taxon.valid?
    expect( taxon.errors ).to be_blank
  end

  it "should prevent grafting an active taxon to an inactive parent" do
    parent = Taxon.make!( rank: Taxon::GENUS, is_active: false )
    taxon = Taxon.make!( name: "balderdash", rank: Taxon::SPECIES )
    expect( taxon.parent_id ).not_to be( parent.id )
    taxon.parent = parent
    taxon.save
    taxon.reload
    expect( taxon.parent_id ).not_to be( parent.id )
  end

  it "should allow grafting an active taxon to an inactive parent if output of draft taxon change" do
    input_taxon = Taxon.make!( rank: Taxon::GENUS, is_active: true )
    output_taxon = Taxon.make!( rank: Taxon::GENUS, is_active: false )
    swap = TaxonSwap.make
    swap.add_input_taxon( input_taxon )
    swap.add_output_taxon( output_taxon )
    swap.save!

    taxon = Taxon.make!( name: "balderdash", rank: Taxon::SPECIES )
    expect( taxon.parent_id ).not_to be( output_taxon.id )
    taxon.parent = output_taxon
    taxon.save
    taxon.reload
    expect( taxon.parent_id ).to be( output_taxon.id )
  end

  context "for complex" do
    before( :all ) { load_test_taxa }

    let( :child_species ) { Taxon.make! name: "Lontra canadensis", rank: "species", parent: @Hylidae }
    let( :child_complex ) { Taxon.make! name: "Lontra canadensis", rank: "complex", parent: @Hylidae }
    let( :child_complex2 ) { Taxon.make! name: "Lontra canadensis", rank: "complex", parent: @Hylidae }

    it "should validate unique name scoped to ancestry and rank" do
      child_complex

      expect { child_complex2 }.to raise_exception ActiveRecord::RecordInvalid,
        "Validation failed: Name already used as a child complex of this taxon's parent"
    end

    it "should allow sibling if no other complex shares name" do
      child_species

      expect { child_complex }.not_to raise_exception
    end
  end
end

describe Taxon, "updating" do
  elastic_models( Observation, Taxon )

  it "should update the ancestry col of all associated listed_taxa"

  it "should not allow a name with a number" do
    t = create :taxon
    t.update( name: "#{t.name}4" )
    expect( t ).not_to be_valid
    expect( t.errors[:name] ).not_to be_blank
  end

  it "should not destroy photos that have observations" do
    t = Taxon.make!
    o = Observation.make!
    p = Photo.make!
    t.photos << p
    make_observation_photo( observation: o, photo: p )
    t.photos = [Photo.make!]
    o.reload
    expect( o.photos ).not_to be_blank
  end

  it "should strip trailing space" do
    t = Taxon.make!( name: "No trailing space" )
    t.update( name: "Trailing space    " )
    expect( t.name ).to eq "Trailing space"
  end
  it "should strip leading space" do
    t = Taxon.make!( name: "No leading space" )
    t.update( name: "    Leading space" )
    expect( t.name ).to eq "Leading space"
  end

  it "should prevent updating a taxon rank to be coarser than the parent" do
    parent = Taxon.make!( rank: Taxon::GENUS )
    taxon = Taxon.new( name: "balderdash", rank: Taxon::SPECIES, parent: parent )
    taxon.save
    taxon.valid?
    expect( taxon.errors ).to be_blank
    taxon.update( rank: Taxon::FAMILY )
    expect( taxon.errors ).not_to be_blank
  end

  it "should prevent updating a taxon rank to be same rank as child" do
    parent = Taxon.make!( rank: Taxon::GENUS )
    taxon = Taxon.new( name: "balderdash", rank: Taxon::SPECIES, parent: parent )
    taxon.save
    taxon.valid?
    expect( taxon.errors ).to be_blank
    parent.update( rank: Taxon::SPECIES )
    expect( parent.errors ).not_to be_blank
  end

  it "should prevent updating a taxon to be inactive if it has active children" do
    taxon = Taxon.make!( name: "balderdash", rank: Taxon::GENUS )
    Taxon.make!( name: "balderdash foo", rank: Taxon::SPECIES, parent: taxon )
    taxon.valid?
    expect( taxon.errors ).to be_blank
    taxon.update( is_active: false )
    expect( taxon.errors ).not_to be_blank
  end

  it "should allow updating a taxon to be inactive if it has active children but move children is checked" do
    taxon = Taxon.make!( name: "balderdash", rank: Taxon::GENUS )
    Taxon.make!( name: "balderdash foo", rank: Taxon::SPECIES, parent: taxon )
    taxon.valid?
    expect( taxon.errors ).to be_blank
    taxon.update( is_active: false, skip_only_inactive_children_if_inactive: true )
    expect( taxon.errors ).to be_blank
  end

  it "should prevent updating a taxon to be active if it has an inactive parent" do
    parent = Taxon.make!( name: "balderdash", rank: Taxon::GENUS, is_active: false )
    taxon = Taxon.make!( name: "balderdash foo", rank: Taxon::SPECIES, parent: parent, is_active: false )
    taxon.valid?
    expect( taxon.errors ).to be_blank
    taxon.update( is_active: true )
    expect( taxon.errors ).not_to be_blank
  end

  it "should allow updating a taxon to be active if it has an inactive parent if output of draft taxon change" do
    input_taxon = Taxon.make!( rank: Taxon::GENUS, is_active: true )
    output_taxon = Taxon.make!( name: "balderdash", rank: Taxon::GENUS, is_active: false )
    swap = TaxonSwap.make
    swap.add_input_taxon( input_taxon )
    swap.add_output_taxon( output_taxon )
    swap.save!

    taxon = Taxon.make!( name: "balderdash foo", rank: Taxon::SPECIES, parent: output_taxon, is_active: false )
    taxon.valid?
    expect( taxon.errors ).to be_blank
    taxon.update( is_active: true )
    expect( taxon.errors ).to be_blank
  end

  describe "auto_description" do
    it "should remove the wikipedia_summary when it changes to false" do
      t = Taxon.make!( wikipedia_summary: "foo" )
      expect( t.wikipedia_summary ).not_to be_blank
      t.update( auto_description: false )
      t.reload
      expect( t.wikipedia_summary ).to be_blank
    end
  end

  it "should assign the updater if explicitly assigned" do
    creator = make_curator
    updater = make_curator
    t = Taxon.make!( creator: creator, updater: creator, rank: Taxon::FAMILY )
    expect( t.updater ).to eq creator
    t.reload
    t.update( rank: Taxon::GENUS, updater: updater )
    t.reload
    expect( t.updater ).to eq updater
  end

  it "should nilify the updater if not explicitly assigned" do
    creator = make_curator
    t = Taxon.make!( creator: creator, updater: creator, rank: Taxon::FAMILY )
    expect( t.updater ).to eq creator
    t = Taxon.find_by_id( t.id )
    t.update( rank: Taxon::GENUS )
    t.reload
    expect( t.updater ).to be_blank
  end

  it "should queue an update_stats_for_observations_of task even if one already exists" do
    t = Taxon.make!( is_active: true )
    t.update( is_active: false )
    expect( Delayed::Job.where( "handler LIKE '%update_stats_for_observations_of%- #{t.id}%'" ).count ).to eq 1
    t.update( is_active: true )
    expect( Delayed::Job.where( "handler LIKE '%update_stats_for_observations_of%- #{t.id}%'" ).count ).to eq 2
    t.update( is_active: false )
    expect( Delayed::Job.where( "handler LIKE '%update_stats_for_observations_of%- #{t.id}%'" ).count ).to eq 3
  end

  describe "reindexing identifications" do
    elastic_models( Identification )
    it "should happen when the rank_level changes" do
      t = Taxon.make!( rank: Taxon::SUBCLASS )
      i = Identification.make!( taxon: t )
      Delayed::Worker.new.work_off
      t.reload
      expect( t.rank_level ).to eq Taxon::SUBCLASS_LEVEL
      i_es = Identification.elastic_search( where: { id: i.id } ).results.results.first
      expect( i_es.taxon.rank_level ).to eq t.rank_level
      t.update( rank: Taxon::CLASS )
      Delayed::Worker.new.work_off
      t.reload
      expect( t.rank_level ).to eq Taxon::CLASS_LEVEL
      i_es = Identification.elastic_search( where: { id: i.id } ).results.results.first
      expect( i_es.taxon.rank_level ).to eq t.rank_level
    end
  end
end

describe Taxon, "destruction" do
  elastic_models( Observation, Taxon )

  it "should work" do
    Taxon.make!.destroy
  end

  it "should queue a job to destroy descendants if orphaned" do
    load_test_taxa
    Delayed::Job.delete_all
    stamp = Time.now
    @Apodiformes.destroy
    jobs = Delayed::Job.where( "created_at >= ?", stamp )
    expect( jobs.select {| j | j.handler =~ /apply_orphan_strategy/m } ).not_to be_blank
  end
end

describe Taxon, "orphan descendant destruction" do
  elastic_models( Observation, Taxon )
  before( :each ) do
    load_test_taxa
  end

  it "should work" do
    child_ancestry_was = @Apodiformes.child_ancestry
    @Apodiformes.update( parent: nil )
    Taxon.update_descendants_with_new_ancestry( @Apodiformes.id, child_ancestry_was )
    expect( @Apodiformes.descendants ).to include( @Calypte_anna )
    child_ancestry_was = @Apodiformes.child_ancestry
    @Apodiformes.destroy
    Taxon.apply_orphan_strategy( child_ancestry_was )
    expect( Taxon.find_by_id( @Calypte_anna.id ) ).to be_blank
  end
end

describe Taxon, "making iconic" do
  before( :each ) do
    load_test_taxa
  end

  it "should set the iconic taxa of descendant taxa to this taxon" do
    expect( @Calypte_anna.iconic_taxon_id ).to be( @Aves.id )
    @Apodiformes.update( is_iconic: true )
    @Calypte_anna.reload
    expect( @Calypte_anna.iconic_taxon_id ).to be( @Apodiformes.id )
  end

  it "should queue a job to change the iconic taxon of descendent observations" do
    expect do
      @Apodiformes.update( is_iconic: true )
    end.to change( Delayed::Job, :count ).by_at_least( 1 )
  end

  it "should NOT set the iconic taxa of descendant taxa if they descend from a lower iconic taxon" do
    expect( @Aves ).to be_is_iconic
    expect( @Chordata ).not_to be_is_iconic
    expect( @Calypte_anna.iconic_taxon_id ).to be( @Aves.id )
    @Chordata.update( is_iconic: true )
    @Calypte_anna.reload
    expect( @Calypte_anna.iconic_taxon_id ).to be( @Aves.id )
  end
end

describe "Updating iconic taxon" do
  before( :each ) do
    load_test_taxa
  end

  it "should set the iconic taxa of descendant taxa" do
    expect( @Calypte_anna.iconic_taxon_id ).to be( @Aves.id )
    @Calypte.update( iconic_taxon: @Apodiformes )
    @Calypte_anna.reload
    expect( @Calypte_anna.iconic_taxon_id ).to be( @Apodiformes.id )
  end

  it "should queue a job to change the iconic taxon of descendent observations" do
    expect do
      @Calypte.update( iconic_taxon: @Apodiformes )
    end.to change( Delayed::Job, :count ).by_at_least( 1 )
  end

  it "should NOT set the iconic taxa of descendant taxa if they descend from a lower iconic taxon" do
    expect( @Aves ).to be_is_iconic
    expect( @Chordata ).not_to be_is_iconic
    expect( @Calypte_anna.iconic_taxon_id ).to be( @Aves.id )
    @Chordata.update( iconic_taxon: @Plantae )
    @Calypte_anna.reload
    expect( @Calypte_anna.iconic_taxon_id ).to be( @Aves.id )
  end
end

describe Taxon, "set_iconic_taxon_for_observations_of" do
  elastic_models( Observation, Taxon )
  before( :each ) do
    load_test_taxa
  end

  it "should set the iconic taxon for observations of descendant taxa" do
    obs = without_delay { Observation.make!( taxon: @Calypte_anna ) }
    expect( @Calypte_anna.iconic_taxon.name ).to eq @Aves.name
    expect( obs.iconic_taxon.name ).to eq @Calypte_anna.iconic_taxon.name
    @Calypte.update( iconic_taxon: @Amphibia )
    expect( @Calypte.iconic_taxon.name ).to eq @Amphibia.name
    @Calypte_anna.reload
    expect( @Calypte_anna.iconic_taxon.name ).to eq @Amphibia.name
    Taxon.set_iconic_taxon_for_observations_of( @Calypte )
    obs.reload
    expect( obs.iconic_taxon.name ).to eq @Amphibia.name
  end

  it "should not change the iconc taxon for observations of other taxa" do
    bird_obs = Observation.make!( taxon: @Calypte_anna )
    frog_obs = Observation.make!( taxon: @Pseudacris_regilla )
    expect( bird_obs.iconic_taxon ).to eq @Aves
    expect( frog_obs.iconic_taxon ).to eq @Amphibia
    @Pseudacris.update( iconic_taxon: @Plantae )
    Taxon.set_iconic_taxon_for_observations_of( @Pseudacris )
    frog_obs.reload
    expect( frog_obs.iconic_taxon ).to eq @Plantae
    bird_obs.reload
    expect( bird_obs.iconic_taxon ).to eq @Aves
  end

  it "should NOT set the iconic taxa of observations of descendant taxa if they descend from a lower iconic taxon" do
    expect( @Aves ).to be_is_iconic
    expect( @Chordata ).not_to be_is_iconic
    expect( @Calypte_anna.iconic_taxon_id ).to be( @Aves.id )
    expect( @Calypte_anna.ancestor_ids ).to include( @Aves.id )
    expect( @Calypte_anna.ancestor_ids ).to include( @Chordata.id )
    obs = Observation.make!( taxon: @Calypte_anna )
    expect( obs.iconic_taxon ).to eq @Aves
    @Chordata.update( iconic_taxon: @Plantae )
    Taxon.set_iconic_taxon_for_observations_of( @Chordata )
    @Calypte_anna.reload
    expect( @Calypte_anna.iconic_taxon ).to eq @Aves
    obs.reload
    expect( obs.iconic_taxon ).to eq @Aves
  end
end

describe Taxon, "normalize_rank" do
  it "should normalize weird ranks" do
    expect( Taxon.normalize_rank( "sp" ) ).to eq "species"
    expect( Taxon.normalize_rank( "ssp" ) ).to eq "subspecies"
    expect( Taxon.normalize_rank( "Gen" ) ).to eq "genus"
  end

  it "should normalize ranks with punctuation" do
    expect( Taxon.normalize_rank( "super-order" ) ).to eq "superorder"
  end
end

describe Taxon, "common_name" do
  it "should default to English if present" do
    t = Taxon.make!
    tn_en = TaxonName.make!( taxon: t, name: "Red Devil", lexicon: TaxonName::LEXICONS[:ENGLISH] )
    TaxonName.make!( taxon: t, name: "Diablo Rojo", lexicon: TaxonName::LEXICONS[:SPANISH] )
    TaxonName.make!( taxon: t, name: "run away!", lexicon: "unspecified" )
    expect( t.common_name ).to eq( tn_en )
  end
  it "should not default to first common if no English or unknown" do
    t = Taxon.make!
    TaxonName.make!( taxon: t, name: "Diablo Rojo", lexicon: TaxonName::LEXICONS[:SPANISH] )
    expect( t.common_name ).to be_blank
  end
end

describe Taxon, "tags_to_taxa" do
  it "should find Animalia and Mollusca" do
    animalia = Taxon.make!( rank: Taxon::PHYLUM, name: "Animalia" )
    aves = Taxon.make!( rank: Taxon::CLASS, name: "Aves", parent: animalia )
    taxa = Taxon.tags_to_taxa( ["Animalia", "Aves"] )
    expect( taxa ).to include( animalia )
    expect( taxa ).to include( aves )
  end

  it "should work on taxonomic machine tags" do
    animalia = Taxon.make!( rank: Taxon::PHYLUM, name: "Animalia" )
    aves = Taxon.make!( rank: Taxon::CLASS, name: "Aves", parent: animalia )
    calypte_anna = Taxon.make!( rank: Taxon::SPECIES, name: "Calypte anna" )
    taxa = Taxon.tags_to_taxa( [
                                "taxonomy:kingdom=Animalia",
                                "taxonomy:class=Aves",
                                "taxonomy:binomial=Calypte anna"
                              ] )
    expect( taxa ).to include( animalia )
    expect( taxa ).to include( aves )
    expect( taxa ).to include( calypte_anna )
  end

  it "should not find inactive taxa" do
    active_taxon = Taxon.make!
    inactive_taxon = Taxon.make!( name: active_taxon.name, is_active: false )
    taxa = Taxon.tags_to_taxa( [active_taxon.name] )
    expect( taxa ).to include( active_taxon )
    expect( taxa ).not_to include( inactive_taxon )
  end

  it "should work for sp" do
    taxon = Taxon.make!( rank: Taxon::GENUS, name: "Mycena" )
    taxa = Taxon.tags_to_taxa( ["#{taxon.name} sp"] )
    expect( taxa ).to include( taxon )
  end

  it "should work for sp." do
    taxon = Taxon.make!( rank: Taxon::GENUS, name: "Mycena" )
    taxa = Taxon.tags_to_taxa( ["#{taxon.name} sp."] )
    expect( taxa ).to include( taxon )
  end

  it "should not strip out sp from Spizella" do
    t = Taxon.make!( name: "Spizella" )
    taxa = Taxon.tags_to_taxa( ["Spizella"] )
    expect( taxa ).to include( t )
  end

  it "should choose names before codes" do
    code_name = TaxonName.make!( name: "HOME", lexicon: "AOU Codes" )
    name_name = TaxonName.make!( name: "Golden-crowned Sparrow", lexicon: "AOU Codes" )
    taxa = Taxon.tags_to_taxa( [code_name.name, name_name.name] )
    expect( taxa.first ).to eq name_name.taxon
  end

  it "should not match a code if it's not an exact match" do
    code_name = TaxonName.make!( name: "HOME", lexicon: "AOU Codes" )
    taxa = Taxon.tags_to_taxa( [code_name.name.downcase] )
    expect( taxa ).to be_blank
  end

  it "should favor longer names" do
    short_name = TaxonName.make!( name: "bork", lexicon: "English" )
    long_name = TaxonName.make!( name: "Giant Dour-Crested Mopple Hopper", lexicon: "English" )
    taxa = Taxon.tags_to_taxa( [short_name.name, long_name.name] )
    expect( taxa.first ).to eq long_name.taxon
  end

  it "should work there are inexact matches" do
    t = Taxon.make!
    TaxonName.make!( name: "Nutria", taxon: t, lexicon: "English" )
    TaxonName.make!( name: "nutria", taxon: t, lexicon: "French" )
    expect( Taxon.tags_to_taxa( %w(Nutria) ) ).to include t
  end

  it "should not match problematic names" do
    Taxon::PROBLEM_NAMES.each do | name |
      t = Taxon.make( name: name.capitalize )
      if t.valid?
        expect( Taxon.tags_to_taxa( [name, name.capitalize] ) ).to be_blank
      end
    end
  end

  it "should not match scientifc names that are 2 letters or less" do
    %w(Aa Io La).each do | name |
      Taxon.make!( name: name, rank: Taxon::GENUS )
      expect( Taxon.tags_to_taxa( [name, name.downcase] ) ).to be_blank
    end
  end

  it "should not match abbreviated month names" do
    %w(Mar May Jun Nov).each do | name |
      Taxon.make!( name: name, rank: Taxon::GENUS )
      expect( Taxon.tags_to_taxa( [name, name.downcase] ) ).to be_blank
    end
  end
end

describe Taxon, "merging" do
  elastic_models( Observation, Taxon )
  before( :all ) { load_test_taxa }
  before( :each ) do
    # load_test_taxa
    @keeper = Taxon.make!(
      name: "Calypte keeper",
      rank: Taxon::SPECIES,
      parent: @Calypte
    )
    @reject = Taxon.make!(
      name: "Calypte reject",
      rank: Taxon::SPECIES,
      parent: @Calypte
    )
    @has_many_assocs = Taxon.reflections.select {| _k, v | v.macro == :has_many }.map {| k, _v | k }
    @has_many_assocs.each {| assoc | @reject.send( assoc ).reload }
  end

  it "should move the reject's children to the keeper" do
    Taxon.make!( name: "Calypte reject rejectus", parent: @reject, rank: Taxon::SUBSPECIES )
    rejected_children = @reject.children
    expect( rejected_children ).not_to be_empty
    @keeper.merge( @reject )
    rejected_children.each do | c |
      c.reload
      expect( c.parent_id ).to eq @keeper.parent_id
    end
  end

  it "should move the reject's taxon_names to the keeper" do
    rejected_taxon_names = @reject.taxon_names
    expect( rejected_taxon_names ).not_to be_empty
    @keeper.merge( @reject )
    rejected_taxon_names.each do | taxon_name |
      taxon_name.reload
      expect( taxon_name.taxon_id ).to be( @keeper.id )
    end
  end

  it "should move the reject's taxon_names to the keeper even if they don't have a lexicon" do
    @reject.taxon_names << build( :taxon_name )
    rejected_taxon_names = @reject.taxon_names
    expect( rejected_taxon_names ).not_to be_empty
    @keeper.merge( @reject )
    rejected_taxon_names.each do | taxon_name |
      taxon_name.reload
      expect( taxon_name.taxon_id ).to be( @keeper.id )
    end
  end

  it "should move the reject's observations to the keeper" do
    2.times do
      Observation.make!( taxon: @reject )
    end
    rejected_observations = @reject.observations.all
    expect( rejected_observations ).not_to be_empty
    @keeper.merge( @reject )
    rejected_observations.each do | observation |
      observation.reload
      expect( observation.taxon_id ).to be( @keeper.id )
    end
  end

  it "should move the reject's listed_taxa to the keeper" do
    3.times do
      ListedTaxon.make!( taxon: @reject )
    end
    rejected_listed_taxa = @reject.listed_taxa.all
    expect( rejected_listed_taxa ).not_to be_empty
    @keeper.merge( @reject )
    rejected_listed_taxa.each do | listed_taxon |
      listed_taxon.reload
      expect( listed_taxon.taxon_id ).to be( @keeper.id )
    end
  end

  it "should move the reject's list_rules to the keeper" do
    rule = ListRule.make!( operand: @Amphibia, operator: "in_taxon?" )
    reject = rule.operand
    keeper = Taxon.make
    keeper.name = "Amphibiatwo"
    keeper.save
    keeper.update( parent: reject.parent )

    keeper.merge( reject )
    rule.reload
    expect( rule.operand_id ).to be( keeper.id )
  end

  it "should move the reject's identifications to the keeper" do
    3.times do
      Identification.make!( taxon: @reject )
    end
    rejected_identifications = @reject.identifications.all
    expect( rejected_identifications ).not_to be_empty
    @keeper.merge( @reject )
    rejected_identifications.each do | identification |
      identification.reload
      expect( identification.taxon_id ).to be( @keeper.id )
    end
  end

  it "should move the reject's taxon_links to the keeper" do
    3.times do
      TaxonLink.make!( taxon: @reject )
    end
    rejected_taxon_links = @reject.taxon_links.all
    expect( rejected_taxon_links ).not_to be_empty
    @keeper.merge( @reject )
    rejected_taxon_links.each do | taxon_link |
      taxon_link.reload
      expect( taxon_link.taxon_id ).to be( @keeper.id )
    end
  end

  it "should move the reject's taxon_photos to the keeper" do
    3.times do
      TaxonPhoto.make!( taxon: @reject )
    end
    rejected_taxon_photos = @reject.taxon_photos.all
    expect( rejected_taxon_photos ).not_to be_empty
    @keeper.merge( @reject )
    rejected_taxon_photos.each do | taxon_photo |
      taxon_photo.reload
      expect( taxon_photo.taxon_id ).to be( @keeper.id )
    end
  end

  it "should mark scinames not matching the keeper as invalid" do
    old_sciname = @reject.scientific_name
    expect( old_sciname ).to be_is_valid
    @keeper.merge( @reject )
    old_sciname.reload
    expect( old_sciname ).not_to be_is_valid
  end

  it "should delete duplicate taxon_names from the reject" do
    old_sciname = @reject.scientific_name
    synonym = old_sciname.dup
    synonym.is_valid = false
    @keeper.taxon_names << synonym
    @keeper.merge( @reject )
    expect( TaxonName.find_by_id( old_sciname.id ) ).to be_nil
  end

  it "should delete listed_taxa from the reject that are invalid"

  it "should destroy the reject" do
    @keeper.merge( @reject )
    expect( Taxon.find_by_id( @reject.id ) ).to be_nil
  end

  it "should not create duplicate listed taxa" do
    lt1 = ListedTaxon.make!( taxon: @keeper )
    ListedTaxon.make!( taxon: @reject, list: lt1.list )
    @keeper.merge( @reject )
    expect( lt1.list.listed_taxa.where( taxon_id: @keeper.id ).count ).to eq 1
  end

  it "should set iconic taxa on children" do
    reject = Taxon.make!( rank: "species" )
    child = Taxon.make!( parent: reject, rank: "subspecies" )
    expect( child.iconic_taxon_id ).not_to eq @keeper.iconic_taxon_id
    expect( child.iconic_taxon_id ).to eq reject.iconic_taxon_id
    @keeper.merge( reject )
    child.reload
    expect( child.iconic_taxon_id ).to eq @keeper.iconic_taxon_id
  end

  it "should set iconic taxa on descendants" do
    expect( @Calypte_anna.iconic_taxon_id ).not_to eq @Pseudacris.iconic_taxon_id
    @Pseudacris.merge( @Calypte )
    @Calypte_anna.reload
    expect( @Calypte_anna.iconic_taxon_id ).to eq @Pseudacris.iconic_taxon_id
  end

  it "should queue a job to set iconic taxon on observations of descendants" do
    Delayed::Job.delete_all
    stamp = Time.now
    @Pseudacris.merge( @Calypte )
    jobs = Delayed::Job.where( "created_at >= ?", stamp )
    expect( jobs.select {| j | j.handler =~ /set_iconic_taxon_for_observations_of/m } ).not_to be_blank
  end

  it "should remove duplicate schemes" do
    ts = TaxonScheme.make!
    t1 = Taxon.make!
    t1.taxon_schemes << ts
    t2 = Taxon.make!
    t2.taxon_schemes << ts
    t1.merge( t2 )
    t1.reload
    expect( t1.taxon_schemes.size ).to eq( 1 )
  end

  it "should set iconic taxon for observations of reject" do
    reject = Taxon.make!
    o = without_delay { Observation.make!( taxon: reject ) }
    expect( o.iconic_taxon ).to be_blank
    without_delay { @keeper.merge( reject ) }
    o.reload
    expect( o.iconic_taxon ).to eq( @keeper.iconic_taxon )
  end

  it "should update subscriptions" do
    s = Subscription.make!( resource: @reject )
    @keeper.merge( @reject )
    s.reload
    expect( s.resource ).to eq @keeper
  end

  it "should not alter with subscriptions to other classess" do
    reject = Taxon.make!( id: 888 )
    keeper = Taxon.make!( id: 999 )
    o = Observation.make!( id: 888 )
    s = Subscription.make!( resource: o )
    keeper.merge( reject )
    s.reload
    expect( s.resource ).to eq( o )
  end
end

describe Taxon, "moving" do
  elastic_models( Observation, Taxon, Identification )

  before( :all ) do
    load_test_taxa
  end

  let( :obs ) do
    t = Taxon.make!( name: "Calypte test", rank: Taxon::SPECIES, parent: @Calypte )
    Observation.make!( taxon: t )
  end

  let( :hummer_genus ) { Taxon.make!( rank: Taxon::GENUS, parent: @Trochilidae ) }

  it "should update the iconic taxon of observations" do
    old_iconic_id = obs.iconic_taxon_id
    taxon = obs.taxon
    taxon.move_to_child_of( @Amphibia )
    taxon.reload
    obs.reload
    expect( obs.iconic_taxon_id ).not_to be( old_iconic_id )
    expect( obs.iconic_taxon_id ).to be( taxon.iconic_taxon_id )
  end

  it "should queue a job to set iconic taxon on observations of descendants" do
    taxon = obs.taxon
    Delayed::Job.delete_all
    stamp = Time.now
    taxon.parent.move_to_child_of( @Amphibia )
    jobs = Delayed::Job.where( "created_at >= ?", stamp )
    expect( jobs.select {| j | j.handler =~ /set_iconic_taxon_for_observations_of/m } ).not_to be_blank
  end

  it "should set iconic taxon on observations of descendants" do
    taxon = obs.taxon
    without_delay do
      taxon.parent.move_to_child_of( @Amphibia )
    end
    obs.reload
    expect( obs.iconic_taxon ).to eq( @Amphibia )
  end

  it "should set iconic taxon on observations of descendants if grafting for the first time" do
    parent = Taxon.make!( rank: Taxon::GENUS )
    taxon = Taxon.make!( parent: parent, rank: Taxon::SPECIES )
    o = without_delay { Observation.make!( taxon: taxon ) }
    expect( o.iconic_taxon ).to be_blank
    without_delay do
      parent.move_to_child_of( @Amphibia )
    end
    o.reload
    expect( o.iconic_taxon ).to eq( @Amphibia )
  end

  it "should not raise an exception if the new parent doesn't exist" do
    taxon = Taxon.make!
    bad_id = Taxon.last.id + 1
    expect do
      taxon.parent_id = bad_id
    end.not_to raise_error
  end

  # this is something we override from the ancestry gem
  it "should queue a job to update descendant ancestries" do
    Delayed::Job.delete_all
    stamp = Time.now
    hummer_genus.update( parent: @Hylidae )
    jobs = Delayed::Job.where( "created_at >= ?", stamp )
    expect( jobs.select {| j | j.handler =~ /update_descendants_with_new_ancestry/m } ).not_to be_blank
  end

  it "should not queue a job to update descendant ancetries if skip_after_move set" do
    Delayed::Job.delete_all
    stamp = Time.now
    hummer_genus.update( parent: @Hylidae, skip_after_move: true )
    jobs = Delayed::Job.where( "created_at >= ?", stamp )
    expect( jobs.select {| j | j.handler =~ /update_descendants_with_new_ancestry/m } ).not_to be_blank
  end

  it "should queue a job to update observation stats if there are observations" do
    Delayed::Job.delete_all
    stamp = Time.now
    Observation.make!( taxon: hummer_genus )
    expect( Observation.of( hummer_genus ).count ).to eq 1
    hummer_genus.update( parent: @Hylidae )
    jobs = Delayed::Job.where( "created_at >= ?", stamp )
    expect( jobs.select {| j | j.handler =~ /update_stats_for_observations_of/m } ).not_to be_blank
  end

  it "should update community taxa" do
    fam = Taxon.make!( name: "Familyone", rank: "family" )
    subfam = Taxon.make!( name: "Subfamilyone", rank: "subfamily", parent: fam )
    gen = Taxon.make!( name: "Genusone", rank: "genus", parent: fam )
    sp = Taxon.make!( name: "Species one", rank: "species", parent: gen )
    o = Observation.make!
    Identification.make!( observation: o, taxon: subfam )
    Identification.make!( observation: o, taxon: sp )
    expect( Identification.of( gen ).exists? ).to be true
    o.reload
    expect( o.taxon ).to eq fam
    Delayed::Worker.new.work_off
    without_delay do
      gen.update( parent: subfam )
    end
    o.reload
    expect( o.taxon ).to eq sp
  end

  it "should reindex descendants" do
    g = Taxon.make!( rank: Taxon::GENUS, parent: @Trochilidae )
    s = Taxon.make!( rank: Taxon::SPECIES, parent: g )
    Delayed::Worker.new.work_off
    s.reload
    es_response = Taxon.elastic_search( where: { id: s.id } ).results.results.first
    expect( es_response.ancestor_ids ).to include @Trochilidae.id
    g.move_to_child_of( @Hylidae )
    Delayed::Worker.new.work_off
    s.reload
    es_response = Taxon.elastic_search( where: { id: s.id } ).results.results.first
    expect( es_response.ancestor_ids ).to include @Hylidae.id
  end

  it "should reindex identifications of the taxon" do
    g = Taxon.make!( rank: Taxon::GENUS, parent: @Trochilidae )
    s = Taxon.make!( rank: Taxon::SPECIES, parent: g )
    g_ident = Identification.make!( taxon: g )
    s_ident = Identification.make!( taxon: s )
    Delayed::Worker.new.work_off
    s.reload
    g_ident_es = Identification.elastic_search( where: { id: g_ident.id } ).results.results.first
    s_ident_es = Identification.elastic_search( where: { id: s_ident.id } ).results.results.first
    expect( g_ident_es.taxon.ancestor_ids ).to include @Trochilidae.id
    expect( s_ident_es.taxon.ancestor_ids ).to include @Trochilidae.id
    expect( s_ident_es.taxon.rank_level ).to eq s.rank_level
    g.move_to_child_of( @Hylidae )
    Delayed::Worker.new.work_off
    s.reload
    g_ident_es = Identification.elastic_search( where: { id: g_ident.id } ).results.results.first
    s_ident_es = Identification.elastic_search( where: { id: s_ident.id } ).results.results.first
    expect( g_ident_es.taxon.ancestor_ids ).to include @Hylidae.id
    expect( s_ident_es.taxon.ancestor_ids ).to include @Hylidae.id
    expect( s_ident_es.taxon.rank_level ).to eq s.rank_level
    g_obs_es = Observation.elastic_search( where: { id: g_ident.observation_id } ).results.results.first
    s_obs_es = Observation.elastic_search( where: { id: s_ident.observation_id } ).results.results.first
    expect( g_obs_es.taxon.ancestor_ids ).to include @Hylidae.id
    expect( s_obs_es.taxon.ancestor_ids ).to include @Hylidae.id
  end
end

describe Taxon, "update_descendants_with_new_ancestry" do
  before( :each ) do
    load_test_taxa
  end
  it "should update the ancestry of descendants" do
    @Calypte.parent = @Hylidae
    child_ancestry_was = @Calypte.child_ancestry
    @Calypte.save
    Taxon.update_descendants_with_new_ancestry( @Calypte.id, child_ancestry_was )
    @Calypte_anna.reload
    expect( @Calypte_anna.ancestry ).to be =~ /^#{@Hylidae.ancestry}/
    expect( @Calypte_anna.ancestry ).to be =~ /^#{@Calypte.ancestry}/
  end
end

describe Taxon do
  describe "featuring" do
    it "should fail if no photos" do
      taxon = Taxon.make!
      taxon.featured_at = Time.now
      expect( taxon.photos ).to be_blank
      taxon.valid?
      expect( taxon.errors[:featured_at] ).not_to be_blank
    end
  end

  describe "locking" do
    it "should cause grafting descendents to fail" do
      taxon = Taxon.make!( locked: true )
      child = Taxon.make!
      expect( child.parent ).not_to be( taxon )
      child.update_attribute( :parent, taxon )
      expect( child.parent ).not_to be( taxon )
    end

    it "should prevent new scientific taxon names of descendents"
  end
end

describe Taxon, "grafting" do
  elastic_models( Observation, Taxon )
  before( :each ) do
    load_test_taxa
    @graftee = Taxon.make!( rank: "species" )
  end

  it "should set iconic taxa on children" do
    expect( @graftee.iconic_taxon_id ).not_to eq @Pseudacris.iconic_taxon_id
    @graftee.update( parent: @Pseudacris )
    @graftee.reload
    expect( @graftee.iconic_taxon_id ).to eq @Pseudacris.iconic_taxon_id
  end

  it "should set iconic taxa on descendants" do
    taxon = Taxon.make!( rank: "subspecies", name: "Craptaculous", parent: @graftee )
    @graftee.update( parent: @Pseudacris )
    taxon.reload
    expect( taxon.iconic_taxon_id ).to eq @Pseudacris.iconic_taxon_id
  end

  it "should queue a job to set iconic taxon on observations of descendants" do
    Delayed::Job.delete_all
    stamp = Time.now
    @graftee.update( parent: @Pseudacris )
    jobs = Delayed::Job.where( "created_at >= ?", stamp )
    expect( jobs.select {| j | j.handler =~ /set_iconic_taxon_for_observations_of/m } ).not_to be_blank
  end

  it "should set the parent of a species based on the polynom genus" do
    t = Taxon.make!( name: "Pseudacris foo" )
    t.graft
    expect( t.parent ).to eq( @Pseudacris )
  end

  it "should update the ancestry of children" do
    f = Taxon.make!( rank: Taxon::FAMILY, name: "Familyone" )
    g = Taxon.make!( rank: Taxon::GENUS, name: "Genusone" )
    s = Taxon.make!( rank: Taxon::SPECIES, name: "Genusone speciesone", parent: g )
    expect( g ).not_to be_grafted
    expect( s.ancestor_ids ).to include g.id
    expect( s.ancestor_ids ).not_to include f.id
    g.update( parent: f )
    Delayed::Worker.new.work_off
    g.reload
    s.reload
    expect( s.ancestor_ids ).to include g.id
    expect( s.ancestor_ids ).to include f.id
  end
end

describe Taxon, "single_taxon_for_name" do
  it "should find varieties" do
    name = "Abies magnifica var. magnifica"
    t = Taxon.make!( name: name, rank: Taxon::VARIETY )
    expect( t ).to be_variety
    expect( t.name ).to eq( "Abies magnifica magnifica" )
    expect( Taxon.single_taxon_for_name( name ) ).to eq( t )
  end

  it "should not choke on parens" do
    t = Taxon.make!( name: "Foo" )
    expect do
      expect( Taxon.single_taxon_for_name( "(Foo" ) ).to eq( t )
    end.not_to raise_error
  end

  it "should find a valid name, not invalid synonyms within the same parent" do
    name = "Foo bar"
    parent = Taxon.make!( rank: Taxon::GENUS )
    valid = Taxon.make!( name: name, parent: parent, rank: Taxon::SPECIES )
    invalid = Taxon.make!( parent: parent, rank: Taxon::SPECIES )
    invalid.taxon_names.create( name: name, is_valid: false, lexicon: TaxonName::SCIENTIFIC_NAMES )
    expect( Taxon.single_taxon_for_name( name ) ).to eq( valid )
  end

  it "should find a single valid name among invalid synonyms" do
    valid = Taxon.make!( parent: Taxon.make!( rank: Taxon::GENUS ), rank: Taxon::SPECIES )
    invalid = Taxon.make!( parent: Taxon.make!( rank: Taxon::GENUS ), rank: Taxon::SPECIES )
    tn = TaxonName.create!( taxon: invalid, name: valid.name, is_valid: false, lexicon: TaxonName::SCIENTIFIC_NAMES )
    all_names = [valid.taxon_names.map( &:name ), invalid.reload.taxon_names.map( &:name )].flatten.uniq
    expect( all_names.size ).to eq 2
    expect( tn.is_valid? ).to eq false
    expect( Taxon.single_taxon_for_name( valid.name ) ).to eq( valid )
  end

  it "should not choose one active taxon among several active synonyms" do
    parent = Taxon.make!( rank: "genus" )
    valid1 = Taxon.make!( :species, parent: parent )
    valid2 = Taxon.make!( :species, parent: parent )
    [valid1, valid2].each do | t |
      TaxonName.make!( taxon: t, name: "Black Oystercatcher", lexicon: TaxonName::ENGLISH )
    end
    expect( Taxon.single_taxon_for_name( "Black Oystercatcher" ) ).to be_nil
  end

  it "should choose the most conservative synonym on a branch" do
    genus = create( :taxon, :as_genus, name: "Foo" )
    species_name = "Foo bar"
    complex = create( :taxon, :as_complex, parent: genus, name: species_name )
    create( :taxon, :as_species, parent: complex, name: species_name )
    expect( Taxon.single_taxon_for_name( species_name ) ).to eq complex
  end

  it "should not choose the most conservative synonym on a branch if skip_conservative_branch_synonym" do
    genus = create( :taxon, :as_genus, name: "Foo" )
    species_name = "Foo bar"
    complex = create( :taxon, :as_complex, parent: genus, name: species_name )
    create( :taxon, :as_species, parent: complex, name: species_name )
    expect( Taxon.single_taxon_for_name( species_name, skip_conservative_branch_synonym: true ) ).to be_blank
  end
end

describe Taxon, "threatened?" do
  elastic_models( Observation, Taxon )
  it "should work for a place"
  it "should work for lat/lon" do
    p = make_place_with_geom
    cs = ConservationStatus.make!( place: p )
    expect( p.contains_lat_lng?( p.latitude, p.longitude ) ).to be true
    t = cs.taxon
    expect( t.threatened?( latitude: p.latitude, longitude: p.longitude ) ).to be true
  end
end

describe Taxon, "geoprivacy" do
  elastic_models( Observation, Taxon )
  it "should choose the maximum privacy relevant to the location" do
    t = Taxon.make!( rank: Taxon::SPECIES )
    p = make_place_with_geom
    ConservationStatus.make!( taxon: t, place: p, geoprivacy: Observation::PRIVATE )
    ConservationStatus.make!( taxon: t )
    expect( t.geoprivacy( latitude: p.latitude, longitude: p.longitude ) ).to eq Observation::PRIVATE
  end

  it "should be open if conservation statuses exist but all are open" do
    t = Taxon.make!( rank: Taxon::SPECIES )
    p = make_place_with_geom
    ConservationStatus.make!( taxon: t, place: p, geoprivacy: Observation::OPEN )
    ConservationStatus.make!( taxon: t, geoprivacy: Observation::OPEN )
    expect( t.geoprivacy( latitude: p.latitude, longitude: p.longitude ) ).to eq Observation::OPEN
  end
end

describe Taxon, "max_geoprivacy" do
  let( :t1 ) { create :taxon, :as_species }
  let( :t2 ) { create :taxon, :as_species }
  let( :taxon_ids ) { [t1.id, t2.id] }
  elastic_models( Observation, Identification )
  it "should be private if one of the taxa has a private global status" do
    create :conservation_status, taxon: t1, geoprivacy: Observation::PRIVATE
    expect( Taxon.max_geoprivacy( taxon_ids ) ).to eq Observation::PRIVATE
  end
  it "should be private if one of the ancestor taxa has a private global status" do
    parent = create :taxon, :as_genus
    create :conservation_status, taxon: parent, geoprivacy: Observation::PRIVATE
    without_delay do
      t1.update( parent: parent )
    end
    expect( t1.ancestor_ids ).to include parent.id
    expect( Taxon.max_geoprivacy( taxon_ids ) ).to eq Observation::PRIVATE
  end
  it "should be nil if none of the taxa have global status" do
    expect( Taxon.max_geoprivacy( taxon_ids ) ).to be_nil
  end
  it "should be open if the global status is obscured but a local country status is open" do
    place = make_place_with_geom( admin_level: Place::COUNTRY_LEVEL )
    create :conservation_status, taxon: t1, geoprivacy: Observation::OPEN, place: place
    create :conservation_status, taxon: t1
    expect(
      Taxon.max_geoprivacy( [t1.id], latitude: place.latitude, longitude: place.longitude )
    ).to eq Observation::OPEN
  end
  it "should be open if the global status is obscured but a local continent status is open" do
    place = make_place_with_geom( admin_level: Place::CONTINENT_LEVEL )
    create :conservation_status, taxon: t1, geoprivacy: Observation::OPEN, place: place
    create :conservation_status, taxon: t1
    expect(
      Taxon.max_geoprivacy( [t1.id], latitude: place.latitude, longitude: place.longitude )
    ).to eq Observation::OPEN
  end
  it "should be obscured if the global status is obscured but a local town status is open" do
    place = make_place_with_geom( admin_level: Place::TOWN_LEVEL )
    create :conservation_status, taxon: t1, geoprivacy: Observation::OPEN, place: place
    create :conservation_status, taxon: t1
    expect(
      Taxon.max_geoprivacy( [t1.id], latitude: place.latitude, longitude: place.longitude )
    ).to eq Observation::OBSCURED
  end
  it "should be obscured if a country status is open and a non-admin place status is obscured" do
    place = make_place_with_geom( admin_level: Place::COUNTRY_LEVEL )
    non_admin_place = make_place_with_geom
    create :conservation_status,
      taxon: t1,
      geoprivacy: Observation::OPEN,
      place: place
    create :conservation_status,
      taxon: t1,
      geoprivacy: Observation::OBSCURED,
      place: non_admin_place
    expect(
      Taxon.max_geoprivacy( [t1.id], latitude: place.latitude, longitude: place.longitude )
    ).to eq Observation::OBSCURED
  end
  it "should be obscured if a country status is obscured a non-admin place status is open" do
    place = make_place_with_geom( admin_level: Place::COUNTRY_LEVEL )
    non_admin_place = make_place_with_geom
    create :conservation_status,
      taxon: t1,
      geoprivacy: Observation::OBSCURED,
      place: place
    create :conservation_status,
      taxon: t1,
      geoprivacy: Observation::OPEN,
      place: non_admin_place
    expect(
      Taxon.max_geoprivacy( [t1.id], latitude: place.latitude, longitude: place.longitude )
    ).to eq Observation::OBSCURED
  end
  it "should be obscured if both taxa are globally obscured but only one is locally open" do
    place = make_place_with_geom
    create :conservation_status, taxon: t1
    create :conservation_status, taxon: t2
    create :conservation_status, taxon: t2, geoprivacy: Observation::OPEN, place: place
    expect(
      Taxon.max_geoprivacy( [t1.id], latitude: place.latitude, longitude: place.longitude )
    ).to eq Observation::OBSCURED
  end
  it "should be open if a continent status is obscured a country status is open" do
    continent = make_place_with_geom( admin_level: Place::CONTINENT_LEVEL )
    country = make_place_with_geom( admin_level: Place::COUNTRY_LEVEL )
    create :conservation_status,
      taxon: t1,
      geoprivacy: Observation::OBSCURED,
      place: continent
    create :conservation_status,
      taxon: t1,
      geoprivacy: Observation::OPEN,
      place: country
    expect(
      Taxon.max_geoprivacy( [t1.id], latitude: country.latitude, longitude: country.longitude )
    ).to eq Observation::OPEN
  end
end

describe Taxon, "to_styled_s" do
  it "should return normal names untouched" do
    expect( Taxon.new( name: "Tom", rank: nil ).to_styled_s ).to eq "Tom"
  end

  it "should italicize genera and below" do
    expect( Taxon.new( name: "Tom", rank: "genus" ).to_styled_s ).to eq "Genus <i>Tom</i>"
    expect( Taxon.new( name: "Tom", rank: "species" ).to_styled_s ).to eq "<i>Tom</i>"
    expect( Taxon.new( name: "Tom", rank: "infraspecies" ).to_styled_s ).to eq "<i>Tom</i>"
  end

  it "should add ranks to genera and above" do
    expect( Taxon.new( name: "Tom", rank: "genus" ).to_styled_s ).to eq "Genus <i>Tom</i>"
    expect( Taxon.new( name: "Tom", rank: "family" ).to_styled_s ).to eq "Family Tom"
    expect( Taxon.new( name: "Tom", rank: "kingdom" ).to_styled_s ).to eq "Kingdom Tom"
  end

  it "should add common name when available" do
    taxon = Taxon.new( name: "Tom", rank: "genus" )
    TaxonName.make!( name: "Common", taxon: taxon, lexicon: TaxonName::LEXICONS[:ENGLISH] )
    taxon.reload
    expect( taxon.to_styled_s ).to eq "Common (Genus <i>Tom</i>)"
  end
end

describe Taxon, "leading_name" do
  it "returns the scientific name if that's all there is" do
    expect( Taxon.make!( name: "Tom" ).leading_name ).to eq "Tom"
  end

  it "returns the common name when available" do
    taxon = Taxon.make!( name: "Tom" )
    TaxonName.make!( name: "Common",
      taxon: taxon, lexicon: TaxonName::LEXICONS[:ENGLISH] )
    expect( taxon.leading_name ).to eq "Common"
  end
end

describe Taxon, "editable_by?" do
  let( :admin ) { make_admin }
  let( :curator ) { make_curator }
  let( :t ) do
    Taxon.make!
  end
  it "should be editable by admins if class" do
    t.update( observations_count: Taxon::NUM_OBSERVATIONS_REQUIRING_ADMIN_TO_EDIT_TAXON + 10 )
    expect( t ).to be_protected_attributes_editable_by( admin )
  end
  it "should be editable by curators if below threshold" do
    t.update( observations_count: Taxon::NUM_OBSERVATIONS_REQUIRING_ADMIN_TO_EDIT_TAXON - 10 )
    expect( t ).to be_protected_attributes_editable_by( curator )
  end
  it "should not be editable by curators if above threshold" do
    t.update( observations_count: Taxon::NUM_OBSERVATIONS_REQUIRING_ADMIN_TO_EDIT_TAXON + 10 )
    expect( t ).not_to be_protected_attributes_editable_by( curator )
  end
  describe "when taxon framework" do
    let( :second_curator ) { make_curator }
    it "should be editable by taxon curators of that taxon" do
      family = Taxon.make!( rank: Taxon::FAMILY )
      genus = Taxon.make!( rank: Taxon::GENUS, parent: family )
      species = Taxon.make!( rank: Taxon::SPECIES, parent: genus )
      tf = TaxonFramework.make!( taxon: family, rank_level: Taxon::RANK_LEVELS[Taxon::SPECIES] )
      TaxonCurator.make!( taxon_framework: tf, user: second_curator )
      expect( species ).to be_editable_by( second_curator )
    end
    it "should be editable by other site curators" do
      family = Taxon.make!( rank: Taxon::FAMILY )
      genus = Taxon.make!( rank: Taxon::GENUS, parent: family )
      species = Taxon.make!( rank: Taxon::SPECIES, parent: genus )
      tf = TaxonFramework.make!( taxon: family, rank_level: Taxon::RANK_LEVELS[Taxon::SPECIES] )
      TaxonCurator.make!( taxon_framework: tf, user: second_curator )
      expect( species ).to be_editable_by( curator )
    end
  end
end

describe Taxon, "get_gbif_id" do
  it "should work" do
    a = Taxon.make!( name: "Chordata", rank: "phylum" )
    t = Taxon.make!( name: "Pseudacris", rank: "genus", parent: a )
    expect( t.get_gbif_id ).not_to be_blank
    expect( t.taxon_scheme_taxa ).not_to be_blank
  end
  it "should not create a TaxonSchemeTaxon for responses that don't match the taxon's name" do
    a = Taxon.make!( name: "Chordata", rank: "phylum" )
    t = Taxon.make!( name: "Sorberacea", rank: "class", parent: a )
    expect( t.get_gbif_id ).to be_blank
    expect( t.taxon_scheme_taxa ).to be_blank
  end
  it "should not error and return GBIF ID is there is no valid scientific name" do
    a = Taxon.make!( name: "Chordata", rank: "phylum" )
    t = Taxon.make!( name: "Dugongidae", rank: "family", parent: a )
    t.taxon_names.update_all( is_valid: false )
    expect { t.get_gbif_id }.not_to raise_error
    expect( t.get_gbif_id ).to_not be_blank
    expect( t.taxon_scheme_taxa ).to be_blank
  end
end

describe "rank helpers" do
  describe "find_species" do
    it "should return self of the taxon is a species" do
      t = Taxon.make!( rank: Taxon::SPECIES )
      expect( t.species ).to eq t
    end
    it "should return the parent if the taxon is a subspecies" do
      species = Taxon.make!( rank: Taxon::SPECIES )
      subspecies = Taxon.make!( rank: Taxon::SUBSPECIES, parent: species )
      expect( subspecies.species ).to eq species
    end
    it "should return nil if the taxon is a hybrid" do
      hybrid = Taxon.make!( name: "Viola × palmata", rank: Taxon::HYBRID )
      expect( hybrid.species ).to be_nil
    end
  end
end

describe "taxon" do
  let( :root ) { Taxon.make!( rank: Taxon::FAMILY ) }
  let( :internode ) { Taxon.make!( rank: Taxon::GENUS, parent: root ) }
  let!( :tip ) { Taxon.make!( rank: Taxon::SPECIES, parent: internode ) }
  let!( :taxon_framework ) { TaxonFramework.make!( taxon: root, rank_level: Taxon::RANK_LEVELS[Taxon::SPECIES] ) }
  let!( :taxon_curator ) { TaxonCurator.make!( taxon_framework: taxon_framework ) }
  it "should recognize that its covered by a taxon framework" do
    expect( tip.upstream_taxon_framework ).not_to be_blank
  end
  it "should recognize that its not covered by a taxon framework" do
    ssp = Taxon.make!( rank: Taxon::SUBSPECIES, parent: tip )
    expect( ssp.upstream_taxon_framework ).to be_blank
  end
  describe "when current_user" do
    describe "is curator" do
      let( :curator ) { make_curator }
      it "should prevent grafting to root" do
        t = Taxon.make( rank: Taxon::GENUS, parent: root, current_user: curator )
        expect( t ).not_to be_valid
      end
      it "should allow grafting to root when inactive" do
        t = Taxon.make( rank: Taxon::GENUS, parent: root, current_user: curator, is_active: false )
        expect( t ).to be_valid
        t.save
        t.reload
        t.update( rank: Taxon::SUBGENUS, current_user: curator )
        expect( t ).to be_valid
        t.reload
        t.update( is_active: true, current_user: curator )
        expect( t ).not_to be_valid
      end
      it "should prevent grafting to internode" do
        t = Taxon.make( rank: Taxon::SPECIES, parent: internode, current_user: curator )
        expect( t ).not_to be_valid
      end
      it "should allow grafting to tip" do
        t = Taxon.make( rank: Taxon::SUBSPECIES, parent: tip, current_user: curator )
        expect( t ).to be_valid
      end
      it "should prevent editing is_active on root" do
        root.update( is_active: false, current_user: curator )
        expect( root ).not_to be_valid
      end
      it "should allow moving root" do
        other_root = Taxon.make!( rank: Taxon::SUPERFAMILY )
        root.update( parent: other_root, current_user: curator )
        expect( root ).to be_valid
      end
      it "should prevent moving internode" do
        expect( internode.upstream_taxon_framework ).not_to be_blank
        other_root = Taxon.make!( rank: Taxon::FAMILY )
        expect( internode.parent ).to eq root
        internode.update( parent: other_root, current_user: curator )
        expect( internode ).not_to be_valid
        expect( internode.parent ).to eq other_root
      end
      it "should prevent moving tip" do
        other_root = Taxon.make!( rank: Taxon::FAMILY )
        tip.update( parent: other_root, current_user: curator )
        expect( tip ).not_to be_valid
      end
    end
    describe "is taxon curator" do
      it "should alow grafting to root" do
        t = Taxon.make( rank: Taxon::GENUS, parent: root, current_user: taxon_curator.user )
        expect( t ).to be_valid
      end
      it "should allow grafting to internode" do
        t = Taxon.make( rank: Taxon::SPECIES, parent: internode, current_user: taxon_curator.user )
        expect( t ).to be_valid
      end
      it "should allow grafting to tip" do
        t = Taxon.make( rank: Taxon::SUBSPECIES, parent: tip, current_user: taxon_curator.user )
        expect( t ).to be_valid
      end
      it "should prevent taxon_curator from grafting to node covered by a overlapping downstream taxon framework" do
        deeper_internode = Taxon.make!( rank: Taxon::SUBGENUS, parent: internode, current_user: taxon_curator.user )
        Taxon.make!( rank: Taxon::SPECIES, parent: deeper_internode, current_user: taxon_curator.user )
        overlapping_downstream_taxon_framework = TaxonFramework.make!( taxon: internode,
          rank_level: Taxon::RANK_LEVELS[Taxon::SPECIES] )
        TaxonCurator.make!( taxon_framework: overlapping_downstream_taxon_framework )
        t = Taxon.make( rank: Taxon::SPECIES, parent: deeper_internode, current_user: taxon_curator.user )
        expect( t ).not_to be_valid
      end
      it "should allow taxon_curator to grafting to node with an overlapping upstream taxon framework" do
        deeper_internode = Taxon.make!( rank: Taxon::SUBGENUS, parent: internode, current_user: taxon_curator.user )
        Taxon.make!( rank: Taxon::SPECIES, parent: deeper_internode, current_user: taxon_curator.user )
        overlapping_downstream_taxon_framework = TaxonFramework.make!( taxon: internode,
          rank_level: Taxon::RANK_LEVELS[Taxon::SPECIES] )
        overlapping_downstream_taxon_framework_taxon_curator = TaxonCurator.make!(
          taxon_framework: overlapping_downstream_taxon_framework
        )
        t = Taxon.make( rank: Taxon::SPECIES, parent: deeper_internode,
          current_user: overlapping_downstream_taxon_framework_taxon_curator.user )
        expect( t ).to be_valid
      end
      it "should allow moving internode" do
        other_root = Taxon.make!( rank: Taxon::FAMILY )
        internode.update( parent: other_root, current_user: taxon_curator.user )
        expect( internode ).to be_valid
      end
      it "should allow moving tip" do
        other_root = Taxon.make!( rank: Taxon::FAMILY )
        tip.update( parent: other_root, current_user: taxon_curator.user )
        expect( tip ).to be_valid
      end
      it "should prevent taxon_curator from moving tip covered by a overlapping downstream taxon framework" do
        other_root = Taxon.make!( rank: Taxon::FAMILY )
        deeper_internode = Taxon.make!( rank: Taxon::SUBGENUS, parent: internode, current_user: taxon_curator.user )
        deepertip = Taxon.make!( rank: Taxon::SPECIES, parent: deeper_internode, current_user: taxon_curator.user )
        overlapping_downstream_taxon_framework = TaxonFramework.make!( taxon: internode,
          rank_level: Taxon::RANK_LEVELS[Taxon::SPECIES] )
        TaxonCurator.make!( taxon_framework: overlapping_downstream_taxon_framework )
        deepertip.update( parent: other_root, current_user: taxon_curator.user )
        expect( deepertip ).not_to be_valid
      end
      it "should allow taxon_curator to move tip with overlapping upstream taxon framework" do
        other_root = Taxon.make!( rank: Taxon::FAMILY )
        deeper_internode = Taxon.make!( rank: Taxon::SUBGENUS, parent: internode, current_user: taxon_curator.user )
        deepertip = Taxon.make!( rank: Taxon::SPECIES, parent: deeper_internode, current_user: taxon_curator.user )
        overlapping_downstream_taxon_framework = TaxonFramework.make!( taxon: internode,
          rank_level: Taxon::RANK_LEVELS[Taxon::SPECIES] )
        overlapping_downstream_taxon_framework_taxon_curator = TaxonCurator.make!(
          taxon_framework: overlapping_downstream_taxon_framework
        )
        deepertip.update( parent: other_root,
          current_user: overlapping_downstream_taxon_framework_taxon_curator.user )
        expect( deepertip ).to be_valid
      end
    end
  end
end

describe "complete_species_count" do
  it "should be nil if no complete taxon framework" do
    t = Taxon.make!
    expect( t.complete_species_count ).to be_nil
  end
  it "should be set if complete taxon framework exists" do
    ancestor = Taxon.make!( rank: Taxon::FAMILY )
    taxon_framework = TaxonFramework.make!( taxon: ancestor, rank_level: Taxon::RANK_LEVELS[Taxon::SPECIES],
      complete: true )
    taxon_curator = TaxonCurator.make!( taxon_framework: taxon_framework )
    t = Taxon.make!( parent: ancestor, rank: Taxon::GENUS, current_user: taxon_curator.user )
    expect( t.complete_species_count ).not_to be_nil
    expect( t.complete_species_count ).to eq 0
  end
  it "should be nil if complete ancestor exists but it is complete at a higher rank" do
    superfamily = Taxon.make!( rank: Taxon::SUPERFAMILY )
    taxon_framework = TaxonFramework.make!( taxon: superfamily, rank_level: Taxon::RANK_LEVELS[Taxon::GENUS],
      complete: true )
    taxon_curator = TaxonCurator.make!( taxon_framework: taxon_framework )
    family = Taxon.make!( rank: Taxon::FAMILY, parent: superfamily, current_user: taxon_curator.user )
    genus = Taxon.make!( rank: Taxon::GENUS, parent: family, current_user: taxon_curator.user )
    Taxon.make!( rank: Taxon::SPECIES, parent: genus, current_user: taxon_curator.user )
    expect( genus.complete_species_count ).to be_nil
  end
  describe "when complete taxon framework" do
    let( :taxon ) { Taxon.make!( rank: Taxon::FAMILY ) }
    let( :taxon_framework ) { TaxonFramework.make!( complete: true, taxon: taxon ) }
    let( :taxon_curator ) { TaxonCurator.make!( taxon_framework: taxon_framework ) }
    it "should count species" do
      Taxon.make!( rank: Taxon::SPECIES, parent: taxon, current_user: taxon_curator.user )
      expect( taxon.complete_species_count ).to eq 1
    end
    it "should not count genera" do
      Taxon.make!( rank: Taxon::GENUS, parent: taxon, current_user: taxon_curator.user )
      expect( taxon.complete_species_count ).to eq 0
    end
    it "should not count hybrids" do
      Taxon.make!( rank: Taxon::HYBRID, parent: taxon, current_user: taxon_curator.user )
      expect( taxon.complete_species_count ).to eq 0
    end
    it "should not count extinct species" do
      extinct_species = Taxon.make!( rank: Taxon::SPECIES, parent: taxon, current_user: taxon_curator.user )
      ConservationStatus.make!( taxon: extinct_species, iucn: Taxon::IUCN_EXTINCT, status: "extinct" )
      extinct_species.reload
      expect( extinct_species.conservation_statuses.first.iucn ).to eq Taxon::IUCN_EXTINCT
      expect( extinct_species.conservation_statuses.first.place ).to be_blank
      expect( taxon.complete_species_count ).to eq 0
    end
    it "should count species with place-specific non-extinct conservation statuses" do
      cs_species = Taxon.make!( rank: Taxon::SPECIES, parent: taxon, current_user: taxon_curator.user )
      ConservationStatus.make!( taxon: cs_species, iucn: Taxon::IUCN_VULNERABLE, status: "VU" )
      cs_species.reload
      expect( cs_species.conservation_statuses.first.iucn ).to eq Taxon::IUCN_VULNERABLE
      expect( cs_species.conservation_statuses.first.place ).to be_blank
      expect( taxon.complete_species_count ).to eq 1
    end
    it "should not count inactive taxa" do
      Taxon.make!( rank: Taxon::SPECIES, parent: taxon, is_active: false, current_user: taxon_curator.user )
      expect( taxon.complete_species_count ).to eq 0
    end
    it "should be nil for species" do
      species = Taxon.make!( rank: Taxon::SPECIES, parent: taxon, current_user: taxon_curator.user )
      expect( species.complete_species_count ).to eq nil
    end
  end
end

describe "current_synonymous_taxa" do
  let( :curator ) { make_curator }
  it "should be the outputs of a split if the split's input was swapped" do
    swap = make_taxon_swap( committer: curator )
    swap.commit
    Delayed::Worker.new.work_off
    split = make_taxon_split( input_taxon: swap.output_taxon, committer: curator )
    split.commit
    Delayed::Worker.new.work_off
    expect( swap.input_taxon.current_synonymous_taxa.map( &:id ).sort ).to eq split.output_taxa.map( &:id ).sort
  end
  it "should follow splits past subsequent changes" do
    split1 = make_taxon_split( committer: curator )
    split1.commit
    Delayed::Worker.new.work_off
    swap = make_taxon_swap( committer: curator, input_taxon: split1.output_taxa[0] )
    swap.commit
    Delayed::Worker.new.work_off
    split2 = make_taxon_split( committer: curator, input_taxon: split1.output_taxa[1] )
    split2.commit
    Delayed::Worker.new.work_off
    split3 = make_taxon_split( committer: curator, input_taxon: split2.output_taxa[0] )
    split3.commit
    Delayed::Worker.new.work_off
    expect( split1.input_taxon.current_synonymous_taxa.map( &:id ).sort ).to eq [
      swap.output_taxon.id,
      split2.output_taxa[1].id,
      split3.output_taxa.map( &:id )
    ].flatten.sort
  end
end

describe "current_synonymous_taxon" do
  let( :curator ) { make_curator }
  it "should be the output of a first-order swap" do
    swap = make_taxon_swap( committer: curator )
    swap.commit
    expect( swap.input_taxon.current_synonymous_taxon ).to eq swap.output_taxon
  end
  it "should be the output of a second-order swap" do
    swap1 = make_taxon_swap( committer: curator )
    swap1.commit
    swap2 = make_taxon_swap( input_taxon: swap1.output_taxon, committer: curator )
    swap2.commit
    expect( swap1.input_taxon.current_synonymous_taxon ).to eq swap2.output_taxon
  end
  it "should not get stuck in a 1-hop loop" do
    swap1 = make_taxon_swap( committer: curator )
    swap1.commit
    swap2 = make_taxon_swap(
      input_taxon: swap1.output_taxon,
      output_taxon: swap1.input_taxon,
      committer: curator
    )
    swap2.commit
    expect( swap1.input_taxon.current_synonymous_taxon ).to be_nil
    expect( swap1.output_taxon.current_synonymous_taxon ).to eq swap1.input_taxon
  end
  it "should not get stuck in a 2-hop loop" do
    swap1 = make_taxon_swap( committer: curator )
    swap1.commit
    swap2 = make_taxon_swap(
      input_taxon: swap1.output_taxon,
      committer: curator
    )
    swap2.commit
    swap3 = make_taxon_swap(
      input_taxon: swap2.output_taxon,
      output_taxon: swap1.input_taxon,
      committer: curator
    )
    swap3.commit
    expect( swap1.input_taxon.current_synonymous_taxon ).to be_nil
    expect( swap1.output_taxon.current_synonymous_taxon ).to eq swap1.input_taxon
  end
  it "should not get stuck in a loop if the taxon has been the input in multiple splits due to reversion" do
    split1 = make_taxon_split( committer: curator )
    split1.commit
    split2 = make_taxon_split( committer: curator, input_taxon: split1.input_taxon )
    split2.commit
    split1.output_taxa.each do | output_taxon |
      expect( split1.input_taxon.current_synonymous_taxa ).not_to include output_taxon
    end
    split2.output_taxa.each do | output_taxon |
      expect( split2.input_taxon.current_synonymous_taxa ).to include output_taxon
    end
    expect( split1.input_taxon.current_synonymous_taxon ).to be_blank
  end
  it "should not get stuck in a no-hop loop" do
    swap1 = make_taxon_swap( committer: curator )
    swap1.commit
    # creating a case that shouldnt be possible with current code
    # but is possible with older data created before curent validations
    swap2 = make_taxon_swap(
      input_taxon: swap1.output_taxon,
      output_taxon: swap1.output_taxon,
      committer: curator,
      validate: false
    )
    swap2.commit
    swap1.input_taxon.update( is_active: false )
    swap1.output_taxon.update( is_active: false )
    expect( swap1.input_taxon.current_synonymous_taxon ).to be_nil
    expect( swap1.output_taxon.current_synonymous_taxon ).to be_nil
  end
  it "should be blank if swapped and then split" do
    swap = make_taxon_swap( committer: curator )
    swap.commit
    split = make_taxon_split( committer: curator, input_taxon: swap.output_taxon )
    split.commit
    expect( swap.input_taxon.current_synonymous_taxon ).to be_blank
  end
end

describe Taxon, "set_photo_from_observations" do
  elastic_models( Observation, Taxon )
  it "does not throw an error if observation photo positions are nil" do
    t = Taxon.make!( rank: "species" )
    o = make_research_grade_observation( taxon: t )
    ObservationPhoto.make!( observation: o, position: 0, photo: Photo.make!( user: o.user ) )
    ObservationPhoto.make!( observation: o, position: nil, photo: Photo.make!( user: o.user ) )
    expect do
      t.set_photo_from_observations
    end.to_not raise_error
  end
end

describe "taxon_framework_relationship" do
  describe "when taxon has a taxon framework relationship" do
    it "should update taxon framework relationship relationship when taxon name changes" do
      genus = Taxon.make!( name: "Taricha", rank: Taxon::GENUS )
      species = Taxon.make!( name: "Taricha torosa", rank: Taxon::SPECIES, parent: genus )
      TaxonFramework.make!( taxon: genus )
      tfr = TaxonFrameworkRelationship.make!
      species.save
      species.update( taxon_framework_relationship_id: tfr.id )
      species.reload
      et = ExternalTaxon.new(
        name: species.name,
        rank: "species",
        parent_name: species.parent.name,
        parent_rank: species.parent.rank,
        taxon_framework_relationship_id: tfr.id
      )
      et.save
      tfr.reload
      expect( tfr.relationship ).to eq "match"
      species.update( name: "Taricha granulosa" )
      tfr.reload
      expect( tfr.relationship ).to eq "one_to_one"
    end
  end
end

describe "audits" do
  it "should not be recorded if wikipedia_title changes from nil to an empty string" do
    t = create :taxon
    expect( t.audits.size ).to eq 1
    expect( t.wikipedia_title ).to be_nil
    t.update( wikipedia_title: "" )
    expect( t.audits.size ).to eq 1
  end
end
