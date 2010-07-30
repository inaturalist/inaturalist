require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Taxon do
  before(:each) do
    load_test_taxa
    @taxon = @Calypte_anna
  end
  
  it "should have a working #grafted method" do
    @taxon.should respond_to(:grafted?)
    @taxon.grafted?.should be(true)
    
    ungrafted = Taxon.create(
      :name => 'Pseudacris crucifer', # Spring Peeper
      :rank => 'species'
    )
    ungrafted.grafted?.should be(false)
    
    @Animalia.grafted?.should be(true)
  end
  
  it "species_or_lower? should be false for Animalia" do
    @Animalia.species_or_lower?.should be(false)
  end
  
  it "species_or_lower? should be true for Pseudacris regilla" do
    @Pseudacris_regilla.species_or_lower?.should be(true)
  end
end

describe Taxon, "creation" do
  
  before(:each) do
    load_test_taxa
    @taxon = Taxon.make(:name => 'Pseudacris imaginarius', :rank => 'species')
  end
  
  it "should set an iconic taxon if this taxon was grafted" do
    @taxon.parent = @Pseudacris
    @taxon.save!
    @taxon.grafted?.should be(true)
    @taxon.reload
    @taxon.iconic_taxon.should eql(@Amphibia)
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
  # fixtures :taxa, :listed_taxa
  
  before(:each) do
    load_test_taxa
  end
  
  it "should update the ancestry col of all associated listed_taxa"
  # 
  # it "update the lft values of all listed_taxa with this taxon" do
  #   old_lft = taxa(:Pseudacris_regilla).lft
  #   taxa(:Pseudacris_regilla).move_to_child_of(taxa(:Life))
  #   taxa(:Pseudacris_regilla).save
  #   listed_taxa(:quentin_life_list_pseudacris_regilla).lft.should be(taxa(:Pseudacris_regilla).lft)
  #   listed_taxa(:quentin_life_list_pseudacris_regilla).lft.should_not be(old_lft)
  # end
end

describe Taxon, "destruction" do
  before(:each) do
    load_test_taxa
  end
  
  it "should work" do
    @Calypte_anna.destroy
  end
end

describe "Changing the iconic taxon of a", Taxon do
  # fixtures :taxa, :observations, :users
  
  before(:each) do
    load_test_taxa
  end
  
  it "should make a it iconic" do
    @Chordata.is_iconic.should be_false
    @Chordata.is_iconic = true
    @Chordata.save
    @Chordata.is_iconic.should be_true
  end
  
  it "should set the iconic taxa of descendant taxa to this taxon" do
    @Apodiformes.logger.info "\n\n\n[INFO] Starting test..."
    @Apodiformes.descendants.count(
      :conditions => ["iconic_taxon_id = ?", @Apodiformes]
    ).should == 0
    @Apodiformes.is_iconic = true
    @Apodiformes.save
    @Apodiformes.descendants.count(
      :conditions => ["iconic_taxon_id != ?", @Apodiformes]
    ).should == 0
  end

  # This test WOULD pass if rspec would goddamn rollback after the previous test correctly
  it "should set the iconic taxa of observations of descendant taxa to this taxon" do
    @Apodiformes.is_iconic.should be_false
    Observation.of(@Apodiformes).count(
      :conditions => ["observations.iconic_taxon_id = ?", @Apodiformes]
    ).should == 0
    @Apodiformes.is_iconic = true
    @Apodiformes.save
    Observation.of(@Apodiformes).count(
      :conditions => ["observations.iconic_taxon_id != ?", @Apodiformes]
    ).should == 0
  end
  
  it "should NOT set the iconic taxa of descendant taxa if they descend from a lower iconic taxon" do
    @Chordata.is_iconic.should be_false
    @Calypte_anna.iconic_taxon.should_not eql(@Chordata)
    @Calypte_anna.iconic_taxon.should eql(@Aves)
    @Chordata.is_iconic = true
    @Chordata.save
    @Chordata.is_iconic.should be_true
    @Calypte_anna.iconic_taxon.should_not eql(@Chordata)
    @Calypte_anna.iconic_taxon.should eql(@Aves)
  end
  
  it "should NOT set the iconic taxa of observations of descendant taxa if they descend from a lower iconic taxon" do
    observation = Observation.make(:taxon => @Calypte_anna)
    @Chordata.is_iconic.should be_false
    observation.iconic_taxon.should_not eql(@Chordata)
    @Chordata.is_iconic = true
    @Chordata.save
    observation.iconic_taxon.should_not eql(@Chordata)
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

describe Taxon, "unique name" do
  # fixtures :taxa, :taxon_names
  # before(:each) do
  #   load_test_taxa
  # end
  # 
  # after(:each) do
  #   unload_test_taxa
  # end
  
  it "should be the default_name by default" do
    taxon = Taxon.make
    taxon.unique_name.should == taxon.default_name.name
  end
  
  # This seems to break unless we use transactional fixtures.  Grr...
  it "should be the scientific name if the common name is already another taxon's unique name" do
    taxon = Taxon.make
    common_name = TaxonName.make(:name => "Most Awesome Radicalbird", 
      :taxon => taxon, 
      :lexicon => TaxonName::LEXICONS[:ENGLISH])
    taxon.save
    taxon.reload
    taxon.unique_name.should == taxon.common_name.name
    
    new_taxon = Taxon.make(:name => "Ballywickia purhiensis", 
      :rank => 'species')
    new_taxon.taxon_names << TaxonName.make(
      :name => taxon.common_name.name, 
      :lexicon => TaxonName::LEXICONS[:ENGLISH]
    )
    new_taxon.reload
    new_taxon.unique_name.should == new_taxon.name
  end
  
  it "should be nil if all else fails" do
    taxon = Taxon.make
    common_name = TaxonName.make(
      :taxon => taxon, 
      :lexicon => TaxonName::LEXICONS[:ENGLISH])
      
    new_taxon = Taxon.make(:name => taxon.name)
    new_common_name = TaxonName.make(:name => common_name.name,
      :taxon => new_taxon, 
      :lexicon => TaxonName::LEXICONS[:ENGLISH])
    
    new_taxon.reload
    new_taxon.taxon_names.each do |tn|
      puts "#{tn} was invalid: " + tn.errors.full_messages.join(', ') unless tn.valid?
    end
    puts "new_taxon was invalid: " + new_taxon.errors.full_messages.join(', ') unless new_taxon.valid?
    new_taxon.unique_name.should be_nil
  end
end

describe Taxon, "tags_to_taxa" do
  # fixtures :taxa
  
  before(:each) do
    load_test_taxa
  end
  
  it "should find Animalia and Mollusca" do
    taxa = Taxon.tags_to_taxa(['Animalia', 'Aves'])
    taxa.should include(@Animalia)
    taxa.should include(@Aves)
  end
  
  it "should work on taxonomic machine tags" do
    taxa = Taxon.tags_to_taxa(['taxonomy:kingdom=Animalia', 'taxonomy:class=Aves'])
    taxa.should include(@Animalia)
    taxa.should include(@Aves)
  end
end

describe Taxon, "merging" do
  # fixtures :taxa, :taxon_names, :observations, :listed_taxa, :list_rules,
  #   :lists, :identifications, :taxon_links, :taxon_photos, :colors
  
  before(:each) do
    load_test_taxa
    @keeper = Taxon.make(
      :name => 'Calypte imaginarius',
      :rank => 'species'
    )
    puts "keeper wasn't valid: " + @keeper.errors.full_messages.join(', ') unless @keeper.valid?
    @reject = @Calypte_anna
    # @keeper.move_to_child_of(@reject.parent)
    @keeper.update_attributes(:parent => @reject.parent)
    @has_many_assocs = Taxon.reflections.select{|k,v| v.macro == :has_many}.map{|k,v| k}
    @has_many_assocs.each {|assoc| @reject.send(assoc, :force_reload => true)}
  end
    
  it "should move the reject's children to the keeper" do
    keeper = Taxon.create(
      :name => 'Pseudacrisplus',
      :rank => 'genus'
    )
    puts "keeper wasn't valid: " + @keeper.errors.full_messages.join(', ') unless @keeper.valid?
    reject = @Pseudacris
    keeper.move_to_child_of(reject.parent)
    
    rejected_children = reject.children
    rejected_children.should_not be_empty
    keeper.merge(reject)
    rejected_children.each do |child|
      child.reload
      child.parent_id.should be(keeper.parent_id)
    end
  end
  
  it "should move the reject's taxon_names to the keeper" do
    rejected_taxon_names = @reject.taxon_names
    rejected_taxon_names.should_not be_empty
    @keeper.merge(@reject)
    rejected_taxon_names.each do |taxon_name|
      taxon_name.reload
      taxon_name.taxon_id.should be(@keeper.id)
    end
  end
  
  it "should move the reject's taxon_names to the keeper even if they don't have a lexicon" do
    @reject.taxon_names << TaxonName.new(:name => "something")
    rejected_taxon_names = @reject.taxon_names
    rejected_taxon_names.should_not be_empty
    @keeper.merge(@reject)
    rejected_taxon_names.each do |taxon_name|
      taxon_name.reload
      taxon_name.taxon_id.should be(@keeper.id)
    end
  end
  
  it "should move the reject's observations to the keeper" do
    2.times do
      Observation.make(:taxon => @reject)
    end
    rejected_observations = @reject.observations.all
    rejected_observations.should_not be_empty
    @keeper.merge(@reject)
    rejected_observations.each do |observation|
      observation.reload
      observation.taxon_id.should be(@keeper.id)
    end
  end
  
  it "should move the reject's listed_taxa to the keeper" do
    3.times do
      ListedTaxon.make(:taxon => @reject)
    end
    rejected_listed_taxa = @reject.listed_taxa.all
    rejected_listed_taxa.should_not be_empty
    @keeper.merge(@reject)
    rejected_listed_taxa.each do |listed_taxon|
      listed_taxon.reload
      listed_taxon.taxon_id.should be(@keeper.id)
    end
  end
  
  it "should move the reject's list_rules to the keeper" do
    # rule = list_rules(:BerkeleyAmphibiansRule)
    rule = ListRule.make(:operand => @Amphibia, :operator => "in_taxon?")
    reject = rule.operand(:force_reload => true)
    keeper = reject.clone
    keeper.name = "Amphibia2"
    keeper.unique_name = "Amphibia2"
    keeper.save
    keeper.update_attributes(:parent => reject.parent)
    
    keeper.merge(reject)
    rule.reload
    rule.operand_id.should be(keeper.id)
  end
  
  it "should move the reject's identifications to the keeper" do
    3.times do
      Identification.make(:taxon => @reject)
    end
    rejected_identifications = @reject.identifications.all
    rejected_identifications.should_not be_empty
    @keeper.merge(@reject)
    rejected_identifications.each do |identification|
      identification.reload
      identification.taxon_id.should be(@keeper.id)
    end
  end
  
  it "should move the reject's taxon_links to the keeper" do
    3.times do
      TaxonLink.make(:taxon => @reject)
    end
    rejected_taxon_links = @reject.taxon_links.all
    rejected_taxon_links.should_not be_empty
    @keeper.merge(@reject)
    rejected_taxon_links.each do |taxon_link|
      taxon_link.reload
      taxon_link.taxon_id.should be(@keeper.id)
    end
  end
  
  it "should move the reject's taxon_photos to the keeper" do
    3.times do
      TaxonPhoto.make(:taxon => @reject)
    end
    rejected_taxon_photos = @reject.taxon_photos.all
    rejected_taxon_photos.should_not be_empty
    @keeper.merge(@reject)
    rejected_taxon_photos.each do |taxon_photo|
      taxon_photo.reload
      taxon_photo.taxon_id.should be(@keeper.id)
    end
  end
  
  it "should move the reject's colors to the keeper"
  
  it "should mark scinames not matching the keeper as invalid" do
    old_sciname = @reject.scientific_name
    old_sciname.should be_is_valid
    @keeper.merge(@reject)
    old_sciname.reload
    old_sciname.should_not be_is_valid
  end
  
  it "should delete duplicate taxon_names from the reject" do
    old_sciname = @reject.scientific_name
    @keeper.taxon_names << old_sciname.clone
    @keeper.merge(@reject)
    TaxonName.find_by_id(old_sciname.id).should be_nil
  end
  
  it "should delete listed_taxa from the reject that are invalid"
  
  it "should destroy the reject" do
    @keeper.merge(@reject)
    TaxonName.find_by_id(@reject.id).should be_nil
  end
end

describe Taxon, "moving" do
  # fixtures :taxa, :observations
  
  before(:each) do
    load_test_taxa
  end
  
  it "should update the iconic taxon of observations" do
    obs = Observation.make(:taxon => @Calypte_anna)
    old_iconic_id = obs.iconic_taxon_id
    taxon = obs.taxon
    taxon.move_to_child_of(@Amphibia)
    taxon.reload
    obs.reload
    obs.iconic_taxon_id.should_not be(old_iconic_id)
    obs.iconic_taxon_id.should be(taxon.iconic_taxon_id)
  end
  
  it "should update the iconic taxon of observations of descendants" do
    obs = Observation.make(:taxon => @Calypte_anna)
    old_iconic_id = obs.iconic_taxon_id
    taxon = obs.taxon
    taxon.parent.move_to_child_of(@Amphibia)
    taxon.reload
    obs.reload
    obs.iconic_taxon_id.should be(taxon.iconic_taxon_id)
  end
end

def load_test_taxa
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

  Rails.logger.debug "[DEBUG] DONE loading test taxa\n\n\n"
end

# def unload_test_taxa
#   # [@Life, @Animalia, @Chordata, @Amphibia, @Hylidae, @Pseudacris,
#   #   @Pseudacris_regilla, @Aves, @Apodiformes, @Trochilidae, @Calypte,
#   #   @Calypte_anna].each(&:destroy)
#   # Taxon.all.each(&:destroy)
#   Taxon.delete_all
#   TaxonName.delete_all
# end
