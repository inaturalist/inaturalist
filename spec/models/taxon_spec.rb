require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Taxon do
  fixtures :taxa
  before(:each) do
    @taxon = Taxon.find_by_name('Calypte anna')
  end
  
  it "should have a working #grafted method" do
    @taxon.should respond_to(:grafted?)
    @taxon.grafted?.should be(true)
    
    ungrafted = Taxon.create(
      :name => 'Pseudacris crucifer', # Spring Peeper
      :rank => 'species'
    )
    ungrafted.grafted?.should be(false)
    
    Taxon.find_by_name('Animalia').grafted?.should be(true)
  end
  
  it "species_or_lower? should be false for Animalia" do
    taxa(:Animalia).species_or_lower?.should be(false)
  end
  
  it "species_or_lower? should be true for Pseudacris regilla" do
    taxa(:Pseudacris_regilla).species_or_lower?.should be(true)
  end
end

describe Taxon, "creation" do
  fixtures :taxa
  
  before(:each) do
    @taxon = Taxon.create(
      :name => 'Pseudacris imaginarius',
      :rank => 'species'
    )
  end
  
  it "should set an iconic taxon if this taxon was grafted" do
    @taxon.move_to_child_of Taxon.find_by_name('Pseudacris')
    @taxon.save
    @taxon.grafted?.should be(true)
    @taxon.reload
    @taxon.iconic_taxon.should eql(taxa(:Amphibia))
  end
  
  it "should create a taxon name with the same name after save" do
    @taxon.reload
    @taxon.taxon_names.should_not be_empty
    @taxon.taxon_names.map(&:name).should include(@taxon.name)
  end
  
  # it "should NOT create a DUPLICATE taxon name with the same name after save" do
  #   @new_taxon = Taxon.new(:name => 'Homo imaginarius', :rank => 'species')
  #   @new_taxon.taxon_names << TaxonName.new(
  #     :name => 'Pseudacris imaginarius',
  #     :is_valid => true
  #   )
  #   
  #   @new_taxon.save
  #   @new_taxon.reload
  #   
  #   @new_taxon.taxon_names.select do |tn| 
  #     tn.name == @new_taxon.name
  #   end.size.should be(1)
  # end
  
  it "should capitalize its name" do
    taxon = Taxon.new(:name => 'balderdash', :rank => 'genus')
    taxon.save
    taxon.name.should == 'Balderdash'
  end
  
  it "should set the rank_level based on the rank" do
    @taxon.rank_level.should == Taxon::RANK_LEVELS[@taxon.rank]
  end
  
  it "should remove leading rank from the name" do
    @taxon.name = "Gen Pseudacris"
    @taxon.save
    @taxon.name.should == 'Pseudacris'
  end
  
  it "should remove internal 'var' from name" do
    @taxon.name = "Quercus agrifolia var. agrifolia"
    @taxon.save
    @taxon.name.should == 'Quercus agrifolia agrifolia'
  end
  
  it "should remove internal 'ssp' from name" do
    @taxon.name = "Quercus agrifolia ssp. agrifolia"
    @taxon.save
    @taxon.name.should == 'Quercus agrifolia agrifolia'
  end
  
  it "should remove internal 'subsp' from name" do
    @taxon.name = "Quercus agrifolia subsp. agrifolia"
    @taxon.save
    @taxon.name.should == 'Quercus agrifolia agrifolia'
  end
end

describe Taxon, "updating" do
  fixtures :taxa, :listed_taxa
  
  it "update the lft values of all listed_taxa with this taxon" do
    old_lft = taxa(:Pseudacris_regilla).lft
    taxa(:Pseudacris_regilla).move_to_child_of(taxa(:Life))
    taxa(:Pseudacris_regilla).save
    listed_taxa(:quentin_life_list_pseudacris_regilla).lft.should be(taxa(:Pseudacris_regilla).lft)
    listed_taxa(:quentin_life_list_pseudacris_regilla).lft.should_not be(old_lft)
  end
end

describe "Changing the iconic taxon of a", Taxon do
  fixtures :taxa, :observations, :users
  
  it "should make a it iconic" do
    taxa(:Chordata).is_iconic.should be_false
    taxa(:Chordata).is_iconic = true
    taxa(:Chordata).save
    taxa(:Chordata).is_iconic.should be_true
  end
  
  it "should set the iconic taxa of descendant taxa to this taxon" do
    taxa(:Apodiformes).logger.info "\n\n\n[INFO] Starting test..."
    taxa(:Apodiformes).descendants.count(
      :conditions => ["iconic_taxon_id = ?", taxa(:Apodiformes)]
    ).should == 0
    taxa(:Apodiformes).is_iconic = true
    taxa(:Apodiformes).save
    taxa(:Apodiformes).descendants.count(
      :conditions => ["iconic_taxon_id != ?", taxa(:Apodiformes)]
    ).should == 0
  end

  # This test WOULD pass if rspec would goddamn rollback after the previous test correctly
  it "should set the iconic taxa of observations of descendant taxa to this taxon" do
    taxa(:Apodiformes).is_iconic.should be_false
    Observation.of(taxa(:Apodiformes)).count(
      :conditions => ["observations.iconic_taxon_id = ?", taxa(:Apodiformes)]
    ).should == 0
    taxa(:Apodiformes).is_iconic = true
    taxa(:Apodiformes).save
    Observation.of(taxa(:Apodiformes)).count(
      :conditions => ["observations.iconic_taxon_id != ?", taxa(:Apodiformes)]
    ).should == 0
  end
  
  it "should NOT set the iconic taxa of descendant taxa if they descend from a lower iconic taxon" do
    taxa(:Chordata).is_iconic.should be_false
    taxa(:Calypte_anna).iconic_taxon.should_not eql(taxa(:Chordata))
    taxa(:Calypte_anna).iconic_taxon.should eql(taxa(:Aves))
    taxa(:Chordata).is_iconic = true
    taxa(:Chordata).save
    taxa(:Chordata).is_iconic.should be_true
    taxa(:Calypte_anna).iconic_taxon.should_not eql(taxa(:Chordata))
    taxa(:Calypte_anna).iconic_taxon.should eql(taxa(:Aves))
  end
  
  it "should NOT set the iconic taxa of observations of descendant taxa if they descend from a lower iconic taxon" do
    taxa(:Chordata).is_iconic.should be_false
    observations(:quentin_saw_annas).iconic_taxon.should_not eql(taxa(:Chordata))
    taxa(:Chordata).is_iconic = true
    taxa(:Chordata).save
    observations(:quentin_saw_annas).iconic_taxon.should_not eql(taxa(:Chordata))
  end
end

describe Taxon, "normalize_rank" do
  it "should normalize weird ranks" do
    Taxon.normalize_rank('sp').should == 'species'
    Taxon.normalize_rank('ssp').should == 'subspecies'
    Taxon.normalize_rank('Gen').should == 'genus'
  end
  
  it "should normalize ranks with punctuation" do
    Taxon.normalize_rank('super-order').should == 'superorder'
  end
end
