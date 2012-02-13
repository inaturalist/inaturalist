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
  
  it "should not destroy photos that have observations" do
    t = Taxon.make
    o = Observation.make
    p = Photo.make
    t.photos << p
    o.photos << p
    t.photos = [Photo.make]
    o.reload
    o.photos.should_not be_blank
  end
end

describe Taxon, "destruction" do
  before(:each) do
    load_test_taxa
  end
  
  it "should work" do
    @Calypte_anna.destroy
  end
  
  it "should queue a job to destroy descendants if orphaned" do
    Delayed::Job.delete_all
    stamp = Time.now
    @Apodiformes.destroy
    jobs = Delayed::Job.all(:conditions => ["created_at >= ?", stamp])
    jobs.select{|j| j.handler =~ /apply_orphan_strategy/m}.should_not be_blank
  end
end

describe Taxon, "orphan descendant destruction" do
  before(:each) do
    load_test_taxa
  end
  
  it "should work" do
    child_ancestry_was = @Apodiformes.child_ancestry
    @Apodiformes.update_attributes(:parent => nil)
    Taxon.update_descendants_with_new_ancestry(@Apodiformes.id, child_ancestry_was)
    @Apodiformes.descendants.should include(@Calypte_anna)
    child_ancestry_was = @Apodiformes.child_ancestry
    @Apodiformes.destroy
    Taxon.apply_orphan_strategy(child_ancestry_was)
    Taxon.find_by_id(@Calypte_anna.id).should be_blank
  end
end

describe "Making a", Taxon, "iconic" do
  before(:each) do
    load_test_taxa
  end
  
  it "should set the iconic taxa of descendant taxa to this taxon" do
    @Calypte_anna.iconic_taxon_id.should be(@Aves.id)
    @Apodiformes.update_attributes(:is_iconic => true)
    @Calypte_anna.reload
    @Calypte_anna.iconic_taxon_id.should be(@Apodiformes.id)
  end
  
  it "should queue a job to change the iconic taxon of descendent observations" do
    expect {
      @Apodiformes.update_attributes(:is_iconic => true)
    }.to change(Delayed::Job, :count).by_at_least(1)
  end
  
  it "should NOT set the iconic taxa of descendant taxa if they descend from a lower iconic taxon" do
    @Aves.should be_is_iconic
    @Chordata.should_not be_is_iconic
    @Calypte_anna.iconic_taxon_id.should be(@Aves.id)
    @Chordata.update_attributes(:is_iconic => true)
    @Calypte_anna.reload
    @Calypte_anna.iconic_taxon_id.should be(@Aves.id)
  end
end

describe "Updating iconic taxon" do
  before(:each) do
    load_test_taxa
  end
  
  it "should set the iconic taxa of descendant taxa" do
    @Calypte_anna.iconic_taxon_id.should be(@Aves.id)
    @Calypte.update_attributes(:iconic_taxon => @Apodiformes)
    @Calypte_anna.reload
    @Calypte_anna.iconic_taxon_id.should be(@Apodiformes.id)
  end
  
  it "should queue a job to change the iconic taxon of descendent observations" do
    expect {
      @Calypte.update_attributes(:iconic_taxon => @Apodiformes)
    }.to change(Delayed::Job, :count).by_at_least(1)
  end
  
  it "should NOT set the iconic taxa of descendant taxa if they descend from a lower iconic taxon" do
    @Aves.should be_is_iconic
    @Chordata.should_not be_is_iconic
    @Calypte_anna.iconic_taxon_id.should be(@Aves.id)
    @Chordata.update_attributes(:iconic_taxon => @Plantae)
    @Calypte_anna.reload
    @Calypte_anna.iconic_taxon_id.should be(@Aves.id)
  end
end

describe Taxon, "set_iconic_taxon_for_observations_of" do
  before(:each) do
    load_test_taxa
  end
  
  it "should set the iconic taxon for observations of descendant taxa" do
    obs = Observation.make(:taxon => @Calypte_anna)
    @Calypte_anna.iconic_taxon.name.should == @Aves.name
    obs.iconic_taxon.name.should == @Calypte_anna.iconic_taxon.name
    @Calypte.update_attributes(:iconic_taxon => @Amphibia)
    @Calypte.iconic_taxon.name.should == @Amphibia.name
    @Calypte_anna.reload
    @Calypte_anna.iconic_taxon.name.should == @Amphibia.name
    Taxon.set_iconic_taxon_for_observations_of(@Calypte)
    obs.reload
    obs.iconic_taxon.name.should == @Amphibia.name
  end
  
  it "should NOT set the iconic taxa of observations of descendant taxa if they descend from a lower iconic taxon" do
    @Aves.should be_is_iconic
    @Chordata.should_not be_is_iconic
    @Calypte_anna.iconic_taxon_id.should be(@Aves.id)
    obs = Observation.make(:taxon => @Calypte_anna)
    obs.iconic_taxon_id.should be(@Aves.id)
    @Chordata.update_attributes(:iconic_taxon => @Plantae)
    Taxon.set_iconic_taxon_for_observations_of(@Chordata)
    @Calypte_anna.reload
    @Calypte_anna.iconic_taxon_id.should be(@Aves.id)
    obs.iconic_taxon_id.should be(@Aves.id)
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

  it "should be the default_name by default" do
    taxon = Taxon.make
    taxon.unique_name.should == taxon.default_name.name.downcase
  end
  
  it "should be the scientific name if the common name is already another taxon's unique name" do
    taxon = Taxon.make
    common_name = TaxonName.make(:name => "Most Awesome Radicalbird", 
      :taxon => taxon, 
      :lexicon => TaxonName::LEXICONS[:ENGLISH])
    taxon.save
    taxon.reload
    taxon.unique_name.should == taxon.common_name.name.downcase
    
    new_taxon = Taxon.make(:name => "Ballywickia purhiensis", 
      :rank => 'species')
    new_taxon.taxon_names << TaxonName.make(
      :name => taxon.common_name.name, 
      :lexicon => TaxonName::LEXICONS[:ENGLISH]
    )
    new_taxon.reload
    new_taxon.unique_name.should == new_taxon.name.downcase
  end
  
  it "should be nil if all else fails" do
    taxon = Taxon.make # unique name should be the common name
    common_name = TaxonName.make(
      :taxon => taxon, 
      :lexicon => TaxonName::LEXICONS[:ENGLISH])
    
    other_taxon = new_taxon = Taxon.make(:name => taxon.name) # unique name should be the sciname
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
  
  it "should work if there are synonyms in different lexicons" do
    taxon = Taxon.make
    name1 = TaxonName.make(:taxon => taxon, :name => "foo", :lexicon => TaxonName::LEXICONS[:ENGLISH])
    name2 = TaxonName.make(:taxon => taxon, :name => "Foo", :lexicon => TaxonName::LEXICONS[:SPANISH])
    taxon.reload
    taxon.unique_name.should_not be_blank
    taxon.unique_name.should == "foo"
  end
  
  it "should not contain punctuation" do
    taxon = Taxon.make
    TaxonName.make(:taxon => taxon, :name => "St. Gerome's Radical Snake", :lexicon => TaxonName::LEXICONS[:ENGLISH])
    taxon.reload
    taxon.unique_name.should_not match(/[\.\'\?\!\\\/]/)
  end
end

describe Taxon, "tags_to_taxa" do
  
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
    rule = ListRule.make(:operand => @Amphibia, :operator => "in_taxon?")
    reject = rule.operand
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
  
  it "should not create duplicate listed taxa" do
    lt1 = ListedTaxon.make(:taxon => @keeper)
    lt2 = ListedTaxon.make(:taxon => @reject, :list => lt1.list)
    @keeper.merge(@reject)
    lt1.list.listed_taxa.count(:conditions => {:taxon_id => @keeper.id}).should == 1
  end
end

describe Taxon, "moving" do
  
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
  
  it "should not raise an exception if the new parent doesn't exist" do
    taxon = Taxon.make
    bad_id = Taxon.last.id + 1
    lambda {
      taxon.parent_id = bad_id
    }.should_not raise_error
  end
  
  # this is something we override from the ancestry gem
  it "should queue a job to update descendant ancetries" do
    Delayed::Job.delete_all
    stamp = Time.now
    @Calypte.update_attributes(:parent => @Hylidae)
    jobs = Delayed::Job.all(:conditions => ["created_at >= ?", stamp])
    jobs.select{|j| j.handler =~ /update_descendants_with_new_ancestry/m}.should_not be_blank
  end
  
end

describe Taxon, "update_descendants_with_new_ancestry" do
  before(:each) do
    load_test_taxa
  end
  it "should update the ancestry of descendants" do
    @Calypte.parent = @Hylidae
    child_ancestry_was = @Calypte.child_ancestry
    @Calypte.save
    Taxon.update_descendants_with_new_ancestry(@Calypte.id, child_ancestry_was)
    @Calypte_anna.reload
    @Calypte_anna.ancestry.should =~ /^#{@Hylidae.ancestry}/
    @Calypte_anna.ancestry.should =~ /^#{@Calypte.ancestry}/
  end
end

describe Taxon do
  describe "featuring" do
    it "should fail if no photos" do
      taxon = Taxon.make
      taxon.featured_at = Time.now
      taxon.photos.should be_blank
      taxon.valid?
      taxon.errors.on(:featured_at).should_not be_blank
    end
  end
  
  describe "conservation status" do
    it "should set conervation_status_source to IUCN by default" do
      taxon = Taxon.make
      taxon.conservation_status_source.should be_blank
      taxon.update_attributes(:conservation_status => Taxon::IUCN_VULNERABLE)
      taxon.conservation_status_source.should_not be_blank
      taxon.conservation_status_source.title.should == 'IUCN Red List of Threatened Species'
    end
    
    it "should define boolean methods" do
      taxon = Taxon.make(:conservation_status => Taxon::IUCN_VULNERABLE)
      taxon.should be_iucn_vulnerable
      taxon.should_not be_iucn_extinct
    end
  end
  
  describe "locking" do
    it "should cause grafting descendents to fail" do
      taxon = Taxon.make(:locked => true)
      child = Taxon.make
      child.parent.should_not be(taxon)
      child.update_attribute(:parent, taxon)
      child.parent.should_not be(taxon)
    end
    
    it "should prevent new scientific taxon names of descendents"
  end
end

# def unload_test_taxa
#   # [@Life, @Animalia, @Chordata, @Amphibia, @Hylidae, @Pseudacris,
#   #   @Pseudacris_regilla, @Aves, @Apodiformes, @Trochilidae, @Calypte,
#   #   @Calypte_anna].each(&:destroy)
#   # Taxon.all.each(&:destroy)
#   Taxon.delete_all
#   TaxonName.delete_all
# end
