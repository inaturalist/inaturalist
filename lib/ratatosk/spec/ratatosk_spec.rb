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
  
  it "should have functional behaves_like_a" do
    expect([]).to behave_like_an(Enumerable)
  end
end

describe Ratatosk::Ratatosk, "creation" do
  it "should accept an array of name providers as a param" do
    col_name_provider = Ratatosk::NameProviders::ColNameProvider.new
    ratatosk = Ratatosk::Ratatosk.new(:name_providers => [col_name_provider])
    ratatosk.name_providers.size.should eq 1
    ratatosk.name_providers.should include(col_name_provider)
  end

  it "shold accept an array of name provider prefixes as a param" do
    ratatosk = Ratatosk::Ratatosk.new(:name_providers => [:col, :ubio])
    ratatosk.name_providers.first.should be_a(Ratatosk::NameProviders::ColNameProvider)
    ratatosk.name_providers.last.should be_a(Ratatosk::NameProviders::UBioNameProvider)
  end
end

describe Ratatosk, "searching" do
  before(:each) do
    @ratatosk = Ratatosk
  end
  
  it "should return an array" do
    @ratatosk.find('Western Bluebird').should be_an(Array)
  end
  
  it "should return TaxonName-like objects that have Taxon-like objects" do
    tn = @ratatosk.find('Western Bluebird')
    tn.each do |taxon_name|
      # puts "DEBUG: #{taxon_name} is a #{taxon_name.class}"
      expect(taxon_name.taxon).not_to be(nil)
      # taxon_name.taxon.should behave_like_a(Taxon)
      expect(taxon_name.taxon.name).not_to be(nil)
    end
  end
  
  it "should return valid names by default" do
    Ratatosk.find('Vulpes vulpes').each do |name|
      unless name.valid?
        puts "ERROR FROM Ratatosk searching should return valid names by default: #{name.errors.full_messages.join(', ')}"
      end
      name.valid?.should be(true)
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
      name.should be_valid
      name.reload
      name.should be_valid
    end
    
    names = TaxonName.find(:all, :conditions => {:name => 'coyote'})
    names.each do |name|
      puts "DEBUG: #{name} is invalid: #{name.errors.full_messages.join(', ')}" unless name.valid?
      name.valid?.should be(true)
      
      puts "DEBUG: #{name.taxon} is invalid: #{name.taxon.errors.full_messages.join(', ')}" unless name.taxon.valid?
      name.taxon.valid?.should be(true)
    end
  end
  
  it "should return homonyms in different phyla" do
    names = Ratatosk.find('Mimulus')
    phyla = names.map do |name|
      name_provider = Ratatosk::NameProviders.const_get(name.taxon.name_provider).new
      name_provider.get_phylum_for(name.taxon)
    end.compact
    phyla.map(&:name).should include('Magnoliophyta')
    phyla.map(&:name).should include('Arthropoda')
  end
  
  it "should not return homonyms in the same phylum" do
    names = Ratatosk.find('Western bluebird')
    phyla = names.map do |name|
      name_provider = Ratatosk::NameProviders.const_get(name.taxon.name_provider).new
      name_provider.get_phylum_for(name.taxon)
    end.compact
    phyla.select{|p| p.name == 'Chordata'}.size.should be(1)
  end
  
  it "should find 'horseshoe crab'" do
    tn = @ratatosk.find('horseshoe crab')
    tn.should have_at_least(1).taxon_name_adapter
  end
  
  it "should return a taxon with a unique name for Holodiscus discolor" do
    tn = @ratatosk.find('Holodiscus discolor').first
    tn.save
    taxon = tn.taxon
    taxon.reload
    expect(taxon.unique_name).not_to be_nil
  end

  it "should add names to existing taxa" do
    load_test_taxa
    ratatosk = Ratatosk::Ratatosk.new(:name_providers => [:col])
    existing = Taxon.find_by_name('Calypte anna')
    expect(existing).not_to be_blank
    results = ratatosk.find('Calypte anna')
    puts "existing: #{existing}"
    results.each do |tn|
      puts "tn: #{tn}"
      tn.taxon.should eq(existing)
    end
  end
end

describe Ratatosk, "grafting" do
  
  before :all do
    load_test_taxa
  end
  
  before(:each) do
    @ratatosk = Ratatosk
  end
  
  it "should set the parent of Homo sapiens to Homo" do
    @homo_sapiens_name = Ratatosk.find('Homo sapiens').first
    @homo_sapiens_name.save
    @homo_sapiens = @homo_sapiens_name.taxon
    @ratatosk.graft(@homo_sapiens)
    @homo_sapiens.reload
    @homo_sapiens.parent.name.should eq 'Homo'
  end
  
  it "should set the parent of a species to genus" do
    nudi = @ratatosk.find('hermissenda crassicornis').first
    nudi.save
    @ratatosk.graft(nudi.taxon)
    nudi.taxon.parent.rank.should eq 'genus'
  end
  
  it "should set the parent of a subspecies to an existing species" do
    enes = Taxon.find_by_name('Ensatina eschscholtzii')
    r = @ratatosk.find('Ensatina eschscholtzii xanthoptica')
    yenes = r.first
    yenes.save
    @ratatosk.graft(yenes.taxon)
    yenes.reload
    yenes.taxon.parent.should eq enes
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
      anna.update_attributes(:parent => calypte)
    end
    anna.should be_grafted
    @ratatosk.graft(anna).should eq []
  end
  
  it "should graft everything to 'Life'" do
    life = Taxon.find_by_name('Life')
    tn = @ratatosk.find('Hexamitidae').first
    tn.save
    @ratatosk.graft(tn.taxon)
    tn.reload
    tn.taxon.ancestors.should include(life)
  end
  
  it "should set the parent of a kingdom to 'Life'" do
    life = Taxon.find_by_name('Life')
    plantae = @ratatosk.find('Plantae').first
    plantae.save
    @ratatosk.graft(plantae.taxon)
    plantae.reload
    plantae.taxon.parent.should eq life
  end
  
  it "should result in taxa that all have scientific names" do
    @homo_sapiens_name = Ratatosk.find('Homo sapiens').first
    @homo_sapiens_name.save
    @homo_sapiens = @homo_sapiens_name.taxon
    Ratatosk.graft(@homo_sapiens).each do |grafted_taxon|
      grafted_taxon.taxon_names.map(&:name).should include(grafted_taxon.name)
    end
  end
  
  # Specific tests
  it "should goddamn work for Cuthona divae" do
    diva = @ratatosk.find('Cuthona divae').first
    diva.save
    @ratatosk.graft(diva.taxon)
    diva.reload
    diva.taxon.parent.rank.should eq 'genus'
    diva.taxon.parent.name.should eq 'Cuthona'
  end

  # Didn't seem to be getting any results as of 2009-10-09
  # it "should work for incense cedar" do
  #   results = @ratatosk.find('incense cedar').select do |name|
  #     name.name == 'incense cedar'
  #   end
  #   puts "DEBUG: results: #{results.join(', ')}"
  #   cedar = results.first
  #   cedar.save
  #   @ratatosk.graft(cedar.taxon)
  #   cedar.reload
  #   cedar.taxon.parent.name.should == 'Cupressaceae'
  #   cedar.taxon.ancestors.first.name.should == 'Life'
  # end
  
  it "should work for royal larkspur" do
    names = @ratatosk.find('royal larkspur')
    names.each(&:save)
    rola = Taxon.find_by_name('Delphinium variegatum')
    @ratatosk.graft(rola)
    rola.reload
    rola.parent.name.should eq "Delphinium"
    rola.phylum.name.should eq 'Magnoliophyta'
    rola.ancestors.first.name.should eq 'Life'
  end
  
  describe "to a locked subtree" do
    it "should fail" do
      @Amphibia.update_attributes(:locked => true)
      taxon = Taxon.make!(:name => "Pseudacris foobar", :rank => Taxon::SPECIES)
      @ratatosk.graft(taxon)
      taxon.reload
      expect(taxon).not_to be_grafted
      expect(taxon.ancestor_ids).not_to include(@Amphibia.id)
    end

    it "should flag taxa that could not be grafted" do
      @Amphibia.update_attributes(:locked => true)
      @Amphibia.should be_valid
      @Amphibia.should be_locked
      # puts "Amphibia.locked: #{@Amphibia.locked}"
      taxon = Taxon.make!(:name => "Pseudacris foobar", :rank => Taxon::SPECIES)
      expect {
        # puts "spec, grafting"
        @ratatosk.graft(taxon)
        taxon.reload
        # puts "taxon.ancestor_ids: #{taxon.ancestor_ids.inspect}"
        expect(taxon).not_to be_grafted
      }.to change(Flag, :count).by_at_least(1)
    end
  end

  it "should look up import a polynom parent" do
    Taxon.find_by_name('Sula leucogaster').should be_blank
    Taxon.find_by_name('Sula').should be_blank
    taxon = Taxon.make!(:name => "Sula leucogaster", :rank => Taxon::SPECIES)
    @ratatosk.graft(taxon)
    expect(taxon.parent).not_to be_blank
    taxon.parent.name.should eq('Sula')
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
    lineage.first.name.should eq gbh.taxon.name
    graft_point.should eq aves
  end
  
  # it "should work for Boloria bellona" do
  #   bobes = @ratatosk.find('Boloria bellona')
  #   puts "bobes.size: #{bobes.size}"
  #   tn = bobes.first
  #   name_provider = Ratatosk::NameProviders.const_get(tn.taxon.name_provider).new
  #   lineage = name_provider.get_lineage_for(tn.taxon)
  #   graft_point, lineage = @ratatosk.get_graft_point_for(lineage)
  #   graft_point.name.should == "Insecta"
  # end
end

def load_test_taxa
  Taxon.delete_all
  TaxonName.delete_all
  Rails.logger.debug "\n\n\n[DEBUG] loading test taxa"
  @Life = Taxon.make!(:name => 'Life')

  @Animalia = Taxon.make!(:name => 'Animalia', :rank => 'kingdom', :is_iconic => true)
  @Animalia.update_attributes(:parent => @Life)

  @Chordata = Taxon.make!(:name => 'Chordata', :rank => "phylum")
  @Chordata.update_attributes(:parent => @Animalia)

  @Amphibia = Taxon.make!(:name => 'Amphibia', :rank => "class", :is_iconic => true)
  @Amphibia.update_attributes(:parent => @Chordata)

  @Hylidae = Taxon.make!(:name => 'Hylidae', :rank => "order")
  @Hylidae.update_attributes(:parent => @Amphibia)

  @Pseudacris = Taxon.make!(:name => 'Pseudacris', :rank => "genus")
  @Pseudacris.update_attributes(:parent => @Hylidae)

  @Pseudacris_regilla = Taxon.make!(:name => 'Pseudacris regilla', :rank => "species")
  @Pseudacris_regilla.update_attributes(:parent => @Pseudacris)
  
  @Caudata = Taxon.make!(:name => 'Caudata', :rank => "order")
  @Caudata.update_attributes(:parent => @Amphibia)
  
  @Ensatina = Taxon.make!(:name => 'Ensatina', :rank => "genus")
  @Ensatina.update_attributes(:parent => @Caudata)

  @Ensatina_eschscholtzii = Taxon.make!(:name => 'Ensatina eschscholtzii', :rank => "species")
  @Ensatina_eschscholtzii.update_attributes(:parent => @Ensatina)
  
  @Aves = Taxon.make!(:name => "Aves", :rank => "class", :is_iconic => true)
  @Aves.update_attributes(:parent => @Chordata)
  
  @Apodiformes = Taxon.make!(:name => "Apodiformes", :rank => "order")
  @Apodiformes.update_attributes(:parent => @Aves)
  
  @Trochilidae = Taxon.make!(:name => "Trochilidae", :rank => "family")
  @Trochilidae.update_attributes(:parent => @Apodiformes)
  
  @Calypte = Taxon.make!(:name => "Calypte", :rank => "genus")
  @Calypte.update_attributes(:parent => @Trochilidae)
  
  @Calypte_anna = Taxon.make!(:name => "Calypte anna", :rank => "species")
  @Calypte_anna.update_attributes(:parent => @Calypte)
  
  @Calypte_anna.taxon_names << TaxonName.make!(:name => "Anna's Hummingbird", 
    :taxon => @Calypte_anna, 
    :lexicon => TaxonName::LEXICONS[:ENGLISH])
    
  @Arthropoda = Taxon.make!(:name => 'Arthropoda', :rank => "phylum")
  @Arthropoda.update_attributes(:parent => @Animalia)

  @Insecta = Taxon.make!(:name => 'Insecta', :rank => "class", :is_iconic => true)
  @Insecta.update_attributes(:parent => @Arthropoda)

  Rails.logger.debug "[DEBUG] DONE loading test taxa\n\n\n"
end
