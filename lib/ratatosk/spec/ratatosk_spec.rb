require File.dirname(__FILE__) + '/spec_helper'

describe Ratatosk::Ratatosk do
  before(:each) do
    @ratatosk = Ratatosk::Ratatosk.new
  end
  
  it "should have a find method" do
    expect(@ratatosk).to respond_to(:find)
  end
  
  it "should have an array of name providers" do
    expect(@ratatosk.name_providers).not_to be(nil)
    @ratatosk.name_providers.each do |np|
      expect(np).to respond_to(:find)
    end
  end
end

describe Ratatosk::Ratatosk, "creation" do
  it "should accept an array of name providers as a param" do
    col_name_provider = Ratatosk::NameProviders::ColNameProvider.new
    ratatosk = Ratatosk::Ratatosk.new(:name_providers => [col_name_provider])
    expect(ratatosk.name_providers.size).to eq 1
    expect(ratatosk.name_providers).to include(col_name_provider)
  end

  it "shold accept an array of name provider prefixes as a param" do
    ratatosk = Ratatosk::Ratatosk.new(:name_providers => [:col, :ubio])
    expect( ratatosk.name_providers.first.class ).to eq Ratatosk::NameProviders::ColNameProvider
    expect( ratatosk.name_providers.last.class ).to eq Ratatosk::NameProviders::UBioNameProvider
  end
end

describe Ratatosk, "searching" do
  before(:each) do
    @ratatosk = Ratatosk
  end
  
  it "should return an array" do
    expect( @ratatosk.find('Western Bluebird').class ).to eq Array
  end
  
  it "should return TaxonName-like objects that have Taxon-like objects" do
    tn = @ratatosk.find('Western Bluebird')
    tn.each do |taxon_name|
      expect(taxon_name.taxon).not_to be(nil)
      expect(taxon_name.taxon.name).not_to be(nil)
    end
  end
  
  it "should return valid names by default" do
    Ratatosk.find('Vulpes vulpes').each do |name|
      unless name.valid?
        puts "ERROR FROM Ratatosk searching should return valid names by default: #{name.errors.full_messages.join(', ')}"
      end
      expect(name.valid?).to be(true)
    end
  end
  
  it "should return valid names that STAY valid" do
    results = Ratatosk.find('Canis latrans')
    results.each do |name|
      name.save
      unless name.valid?
        puts "[DEBUG] #{name} was invalid: #{name.errors.full_messages.join(', ')}"
        unless name.taxon.valid?
          puts "[DEBUG] #{name.taxon} was invalid: #{name.taxon.errors.full_messages.join(', ')}"
        end
      end
      expect(name).to be_valid
      name.reload
      expect(name).to be_valid
    end
    
    names = TaxonName.where( name: "coyote" )
    names.each do |name|
      puts "DEBUG: #{name} is invalid: #{name.errors.full_messages.join(', ')}" unless name.valid?
      expect(name.valid?).to be(true)
      
      puts "DEBUG: #{name.taxon} is invalid: #{name.taxon.errors.full_messages.join(', ')}" unless name.taxon.valid?
      expect(name.taxon.valid?).to be(true)
    end
  end
  
  it "should return homonyms in different phyla" do
    names = Ratatosk.find('Mimulus')
    phyla = names.map do |name|
      name_provider = Ratatosk::NameProviders.const_get(name.taxon.name_provider).new
      name_provider.get_phylum_for(name.taxon)
    end.compact
    expect(phyla.map(&:name)).to include('Magnoliophyta')
    expect(phyla.map(&:name)).to include('Arthropoda')
  end
  
  it "should not return homonyms in the same phylum" do
    names = Ratatosk.find('Western bluebird')
    phyla = names.map do |name|
      name_provider = Ratatosk::NameProviders.const_get(name.taxon.name_provider).new
      name_provider.get_phylum_for(name.taxon)
    end.compact
    expect(phyla.select{|p| p.name == 'Chordata'}.size).to be(1)
  end
  
  it "should find 'horseshoe crab'" do
    expect( @ratatosk.find('horseshoe crab') ).not_to be_blank
  end

  it "should add names to existing taxa" do
    load_test_taxa
    ratatosk = Ratatosk::Ratatosk.new(:name_providers => [:col])
    existing = Taxon.find_by_name('Calypte anna')
    expect(existing).not_to be_blank
    results = ratatosk.find('Calypte anna')
    results.each do |tn|
      expect(tn.taxon).to eq(existing)
    end
  end
end

describe Ratatosk, "grafting" do
  
  before do
    load_test_taxa
  end
  
  before(:each) do
    @ratatosk = Ratatosk::Ratatosk.new
  end
  
  it "should set the parent of Homo sapiens to Homo" do
    @homo_sapiens_name = Ratatosk.find('Homo sapiens').first
    @homo_sapiens_name.save
    @homo_sapiens = @homo_sapiens_name.taxon
    @ratatosk.graft(@homo_sapiens)
    @homo_sapiens.reload
    expect(@homo_sapiens.parent.name).to eq 'Homo'
  end
  
  it "should set the parent of a species to genus" do
    nudi = @ratatosk.find('hermissenda crassicornis').first
    nudi.save
    @ratatosk.graft(nudi.taxon)
    expect(nudi.taxon.parent.rank).to eq 'genus'
  end
  
  it "should set the parent of a subspecies to an existing species" do
    enes = Taxon.find_by_name('Ensatina eschscholtzii')
    r = @ratatosk.find('Ensatina eschscholtzii xanthoptica')
    yenes = r.first
    yenes.save
    @ratatosk.graft(yenes.taxon)
    yenes.reload
    expect(yenes.taxon.parent).to eq enes
  end
  
  it "should not set the parent of a subspecies to a genus" do
    taxon = Taxon.make!(:name => "Foo", :rank => "genus")
    new_taxon = Taxon.make!(:name => "Foo bar baz", :rank => "subspecies")
    @ratatosk.graft(new_taxon)
    new_taxon.reload
    expect(new_taxon.parent).not_to eq taxon
  end
  
  it "should not graft homonyms in different phyla to the same parent"
  
  it "should return [] for taxon that is already in the tree" do
    anna = Taxon.find_by_name("Calypte anna")
    calypte = Taxon.find_by_name("Calypte")
    unless anna.grafted?
      anna.update(:parent => calypte)
    end
    expect(anna).to be_grafted
    expect(@ratatosk.graft(anna)).to eq []
  end

  it "should graft everything to 'Life'" do
    life = Taxon.find_by_name('Life')
    tn = @ratatosk.find('Hexamitidae').first
    tn.save
    @ratatosk.graft(tn.taxon)
    tn.reload
    expect(tn.taxon.ancestors).to include(life)
  end
  
  it "should set the parent of a kingdom to 'Life'" do
    life = Taxon.find_by_name('Life')
    plantae = @ratatosk.find('Plantae').first
    plantae.taxon.current_user = make_admin
    plantae.save
    @ratatosk.graft(plantae.taxon)
    plantae.reload
    expect(plantae.taxon.parent).to eq life
  end
  
  it "should result in taxa that all have scientific names" do
    @homo_sapiens_name = Ratatosk.find('Homo sapiens').first
    @homo_sapiens_name.save!
    @homo_sapiens = @homo_sapiens_name.taxon
    @homo_sapiens.reload
    Ratatosk.graft(@homo_sapiens).each do |grafted_taxon|
      expect(grafted_taxon.taxon_names.map(&:name)).to include(grafted_taxon.name)
    end
  end
  
  # Specific tests
  it "should goddamn work for Cuthona divae" do
    diva = @ratatosk.find('Cuthona divae').first
    diva.save
    @ratatosk.graft(diva.taxon)
    diva.reload
    expect(diva.taxon.parent.rank).to eq 'genus'
    expect(diva.taxon.parent.name).to eq 'Cuthona'
  end
  
  describe "to a locked subtree" do
    it "should fail" do
      @Amphibia.update(:locked => true)
      taxon = Taxon.make!(:name => "Pseudacris foobar", :rank => Taxon::SPECIES)
      @ratatosk.graft(taxon)
      taxon.reload
      expect(taxon).not_to be_grafted
      expect(taxon.ancestor_ids).not_to include(@Amphibia.id)
    end

    it "should be idempotent" do
      @Amphibia.update(:locked => true)
      taxon = Taxon.make!(:name => "Pseudacris foobar", :rank => Taxon::SPECIES)
      @ratatosk.graft(taxon)
      taxon.reload
      expect(taxon).not_to be_grafted
      expect(taxon.ancestor_ids).not_to include(@Amphibia.id)
    end

    it "should flag taxa that could not be grafted" do
      @Amphibia.update(:locked => true)
      expect(@Amphibia).to be_valid
      expect(@Amphibia).to be_locked
      taxon = Taxon.make!(:name => "Pseudacris foobar", :rank => Taxon::SPECIES)
      expect {
        @ratatosk.graft(taxon)
        taxon.reload
        expect(taxon).not_to be_grafted
      }.to change(Flag, :count).by_at_least(1)
    end
  end

  it "should look up import a polynom parent" do
    expect(Taxon.find_by_name('Sula leucogaster')).to be_blank
    expect(Taxon.find_by_name('Sula')).to be_blank
    taxon = Taxon.make!(:name => "Sula leucogaster", :rank => Taxon::SPECIES)
    @ratatosk.graft(taxon)
    expect(taxon.parent).not_to be_blank
    expect(taxon.parent.name).to eq('Sula')
  end
end

describe Ratatosk, "get_graft_point_for" do
  before :all do
    load_test_taxa
  end
  
  before(:each) do
    @ratatosk = Ratatosk::Ratatosk.new
  end
  
  it "should get the graft point for a lineage" do
    aves = Taxon.find_by_name('Aves')
    gbh = @ratatosk.find('Great Blue Heron').first
    gbh.save
    
    name_provider = Ratatosk::NameProviders.const_get(gbh.taxon.name_provider).new
    lineage = name_provider.get_lineage_for(gbh.taxon)
    graft_point, lineage = @ratatosk.get_graft_point_for(lineage)
    expect(lineage.first.name).to eq gbh.taxon.name
    expect(graft_point).to eq aves
  end
  
end

def load_test_taxa
  Taxon.delete_all
  TaxonName.delete_all
  Rails.logger.debug "\n\n\n[DEBUG] loading test taxa"
  @Life = Taxon.make!( name: "Life", rank: Taxon::STATEOFMATTER )

  @Animalia = Taxon.make!(:name => 'Animalia', :rank => 'kingdom', :is_iconic => true)
  @Animalia.update(:parent => @Life)

  @Chordata = Taxon.make!(:name => 'Chordata', :rank => "phylum")
  @Chordata.update(:parent => @Animalia)

  @Amphibia = Taxon.make!(:name => 'Amphibia', :rank => "class", :is_iconic => true)
  @Amphibia.update(:parent => @Chordata)

  @Hylidae = Taxon.make!(:name => 'Hylidae', :rank => "order")
  @Hylidae.update(:parent => @Amphibia)

  @Pseudacris = Taxon.make!(:name => 'Pseudacris', :rank => "genus")
  @Pseudacris.update(:parent => @Hylidae)

  @Pseudacris_regilla = Taxon.make!(:name => 'Pseudacris regilla', :rank => "species")
  @Pseudacris_regilla.update(:parent => @Pseudacris)
  
  @Caudata = Taxon.make!(:name => 'Caudata', :rank => "order")
  @Caudata.update(:parent => @Amphibia)
  
  @Ensatina = Taxon.make!(:name => 'Ensatina', :rank => "genus")
  @Ensatina.update(:parent => @Caudata)

  @Ensatina_eschscholtzii = Taxon.make!(:name => 'Ensatina eschscholtzii', :rank => "species")
  @Ensatina_eschscholtzii.update(:parent => @Ensatina)
  
  @Aves = Taxon.make!(:name => "Aves", :rank => "class", :is_iconic => true)
  @Aves.update(:parent => @Chordata)
  
  @Apodiformes = Taxon.make!(:name => "Apodiformes", :rank => "order")
  @Apodiformes.update(:parent => @Aves)
  
  @Trochilidae = Taxon.make!(:name => "Trochilidae", :rank => "family")
  @Trochilidae.update(:parent => @Apodiformes)
  
  @Calypte = Taxon.make!(:name => "Calypte", :rank => "genus")
  @Calypte.update(:parent => @Trochilidae)
  
  @Calypte_anna = Taxon.make!(:name => "Calypte anna", :rank => "species")
  @Calypte_anna.update(:parent => @Calypte)
  
  @Calypte_anna.taxon_names << TaxonName.make!(:name => "Anna's Hummingbird", 
    :taxon => @Calypte_anna, 
    :lexicon => TaxonName::LEXICONS[:ENGLISH])
    
  @Arthropoda = Taxon.make!(:name => 'Arthropoda', :rank => "phylum")
  @Arthropoda.update(:parent => @Animalia)

  @Insecta = Taxon.make!(:name => 'Insecta', :rank => "class", :is_iconic => true)
  @Insecta.update(:parent => @Arthropoda)

  Rails.logger.debug "[DEBUG] DONE loading test taxa\n\n\n"
end
