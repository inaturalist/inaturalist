require File.dirname(__FILE__) + '/spec_helper'

describe Ratatosk::Ratatosk do
  before(:each) do
    @ratatosk = Ratatosk::Ratatosk.new
  end
  
  it "should have a find method" do
    @ratatosk.should respond_to(:find)
  end
  
  it "should have an array of name providers" do
    @ratatosk.name_providers.should_not be(nil)
    @ratatosk.name_providers.each do |np|
      np.should respond_to(:find)
    end
  end
  
  it "should have functional be_a" do
    "fortinbras".should be_a(String)
  end
  
  it "should have functional behaves_like_a" do
    [].should behave_like_an(Enumerable)
  end
end

describe Ratatosk::Ratatosk, "creation" do
  it "should accept an array of name providers as a param" do
    col_name_provider = Ratatosk::NameProviders::ColNameProvider.new
    ratatosk = Ratatosk::Ratatosk.new(:name_providers => [col_name_provider])
    ratatosk.name_providers.size.should == 1
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
      taxon_name.taxon.should_not be(nil)
      taxon_name.taxon.should behave_like_a(Taxon)
      taxon_name.taxon.name.should_not be(nil)
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
    taxon.unique_name.should_not be_nil
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
    @homo_sapiens.parent.name.should == 'Homo'
  end
  
  it "should set the parent of a species to genus" do
    nudi = @ratatosk.find('hermissenda crassicornis').first
    nudi.save
    @ratatosk.graft(nudi.taxon)
    nudi.taxon.parent.rank.should == 'genus'
  end
  
  it "should set the parent of a subspecies to an existing species" do
    enes = Taxon.find_by_name('Ensatina eschscholtzii')
    r = @ratatosk.find('Ensatina eschscholtzii xanthoptica')
    yenes = r.first
    yenes.save
    @ratatosk.graft(yenes.taxon)
    yenes.reload
    yenes.taxon.parent.should == enes
  end
  
  it "should not set the parent of a subspecies to a genus" do
    taxon = Taxon.make(:name => "Foo", :rank => "genus")
    new_taxon = Taxon.make(:name => "Foo bar baz", :rank => "subspecies")
    @ratatosk.graft(new_taxon)
    new_taxon.reload
    new_taxon.parent.should_not == taxon
  end
  
  it "should not graft homonyms in different phyla to the same parent"
  
  it "should return [] for taxon that is already in the tree" do
    anna = Taxon.find_by_name("Calypte anna")
    calypte = Taxon.find_by_name("Calypte")
    unless anna.grafted?
      anna.update_attributes(:parent => calypte)
    end
    anna.should be_grafted
    @ratatosk.graft(anna).should == []
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
    plantae.taxon.parent.should == life
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
    diva.taxon.parent.rank.should == 'genus'
    diva.taxon.parent.name.should == 'Cuthona'
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
    rola.parent.name.should == "Delphinium"
    rola.phylum.name.should == 'Magnoliophyta'
    rola.ancestors.first.name.should == 'Life'
  end
  
  describe "to a locked subtree" do
    it "should fail" do
      @Amphibia.update_attributes(:locked => true)
      taxon = Taxon.make(:name => "Ensatina foobar")
      @ratatosk.graft(taxon)
      taxon.reload
      taxon.ancestor_ids.should_not include(@Amphibia.id)
    end

    it "should flag taxa that could not be grafted" do
      @Amphibia.update_attributes(:locked => true)
      taxon = Taxon.make(:name => "Ensatina foobar")
      lambda {
        @ratatosk.graft(taxon)
      }.should change(Flag, :count).by_at_least(1)
    end
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
    lineage.first.name.should == gbh.taxon.name
    graft_point.should == aves
  end
  
  it "should work for Boloria bellona" do
    bobes = @ratatosk.find('Boloria bellona')
    tn = bobes.first
    name_provider = Ratatosk::NameProviders.const_get(tn.taxon.name_provider).new
    lineage = name_provider.get_lineage_for(tn.taxon)
    graft_point, lineage = @ratatosk.get_graft_point_for(lineage)
    graft_point.name.should == "Insecta"
  end
end

def load_test_taxa
  Taxon.delete_all
  TaxonName.delete_all
  Rails.logger.debug "\n\n\n[DEBUG] loading test taxa"
  @Life = Taxon.make(:name => 'Life')

  @Animalia = Taxon.make(:name => 'Animalia', :rank => 'kingdom', :is_iconic => true)
  @Animalia.update_attributes(:parent => @Life)

  @Chordata = Taxon.make(:name => 'Chordata', :rank => "phylum")
  @Chordata.update_attributes(:parent => @Animalia)

  @Amphibia = Taxon.make(:name => 'Amphibia', :rank => "class", :is_iconic => true)
  @Amphibia.update_attributes(:parent => @Chordata)

  @Hylidae = Taxon.make(:name => 'Hylidae', :rank => "order")
  @Hylidae.update_attributes(:parent => @Amphibia)

  @Pseudacris = Taxon.make(:name => 'Pseudacris', :rank => "genus")
  @Pseudacris.update_attributes(:parent => @Hylidae)

  @Pseudacris_regilla = Taxon.make(:name => 'Pseudacris regilla', :rank => "species")
  @Pseudacris_regilla.update_attributes(:parent => @Pseudacris)
  
  @Caudata = Taxon.make(:name => 'Caudata', :rank => "order")
  @Caudata.update_attributes(:parent => @Amphibia)
  
  @Ensatina = Taxon.make(:name => 'Ensatina', :rank => "genus")
  @Ensatina.update_attributes(:parent => @Caudata)

  @Ensatina_eschscholtzii = Taxon.make(:name => 'Ensatina eschscholtzii', :rank => "species")
  @Ensatina_eschscholtzii.update_attributes(:parent => @Ensatina)
  
  @Aves = Taxon.make(:name => "Aves", :rank => "class", :is_iconic => true)
  @Aves.update_attributes(:parent => @Chordata)
  
  @Apodiformes = Taxon.make(:name => "Apodiformes", :rank => "order")
  @Apodiformes.update_attributes(:parent => @Aves)
  
  @Trochilidae = Taxon.make(:name => "Trochilidae", :rank => "family")
  @Trochilidae.update_attributes(:parent => @Apodiformes)
  
  @Calypte = Taxon.make(:name => "Calypte", :rank => "genus")
  @Calypte.update_attributes(:parent => @Trochilidae)
  
  @Calypte_anna = Taxon.make(:name => "Calypte anna", :rank => "species")
  @Calypte_anna.update_attributes(:parent => @Calypte)
  
  @Calypte_anna.taxon_names << TaxonName.make(:name => "Anna's Hummingbird", 
    :taxon => @Calypte_anna, 
    :lexicon => TaxonName::LEXICONS[:ENGLISH])
    
  @Arthropoda = Taxon.make(:name => 'Arthropoda', :rank => "phylum")
  @Arthropoda.update_attributes(:parent => @Animalia)

  @Insecta = Taxon.make(:name => 'Insecta', :rank => "class", :is_iconic => true)
  @Insecta.update_attributes(:parent => @Arthropoda)

  Rails.logger.debug "[DEBUG] DONE loading test taxa\n\n\n"
end
