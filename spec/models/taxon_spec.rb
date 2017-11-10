require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Taxon do
  before(:each) { enable_elastic_indexing( Observation, Taxon ) }
  after(:each) { disable_elastic_indexing( Observation, Taxon ) }

  before(:each) do
    load_test_taxa
    @taxon = @Calypte_anna
  end
  
  it "should have a working #grafted method" do
    expect(@taxon).to respond_to(:grafted?)
    expect(@taxon.grafted?).to be(true)
    
    ungrafted = Taxon.create(
      :name => 'Pseudacris crucifer', # Spring Peeper
      :rank => 'species'
    )
    expect(ungrafted.grafted?).to be(false)
    
    expect(@Animalia.grafted?).to be(true)
  end
  
  it "species_or_lower? should be false for Animalia" do
    expect(@Animalia.species_or_lower?).to be(false)
  end
  
  it "species_or_lower? should be true for Pseudacris regilla" do
    expect(@Pseudacris_regilla.species_or_lower?).to be(true)
  end
end

describe Taxon, "creation" do
  before(:each) { enable_elastic_indexing( Observation, Taxon ) }
  after(:each) { disable_elastic_indexing( Observation, Taxon ) }
  
  before(:each) do
    load_test_taxa
    @taxon = Taxon.make!(:name => 'Pseudacris imaginarius', :rank => 'species')
  end
  
  it "should set an iconic taxon if this taxon was grafted" do
    @taxon.parent = @Pseudacris
    @taxon.save!
    expect(@taxon.grafted?).to be(true)
    @taxon.reload
    expect(@taxon.iconic_taxon).to eql(@Amphibia)
  end
  
  it "should create a taxon name with the same name after save" do
    @taxon.reload
    expect(@taxon.taxon_names).not_to be_empty
    expect(@taxon.taxon_names.map(&:name)).to include(@taxon.name)
  end

  it "should create a taxon name with the same name after save even if invalid on source_identifier" do
    source_identifier = "foo"
    source = Source.make!
    existing = TaxonName.make!(:source => source, :source_identifier => source_identifier)
    t = Taxon.make!(:source => source, :source_identifier => source_identifier)
    expect(t.taxon_names.map(&:name)).to include(t.name)
  end
  
  it "should capitalize its name" do
    taxon = Taxon.new(:name => 'balderdash', :rank => 'genus')
    taxon.save
    expect(taxon.name).to eq 'Balderdash'
  end

  it "should capitalize hybrid genera correclty" do
    taxon = Taxon.make!(name: "× chitalpa", rank: "genus")
    expect( taxon.name ).to eq "× Chitalpa"
    taxon = Taxon.make!(name: "× Chitalpa", rank: "genus")
    expect( taxon.name ).to eq "× Chitalpa"
  end
  
  it "should set the rank_level based on the rank" do
    expect(@taxon.rank_level).to eq Taxon::RANK_LEVELS[@taxon.rank]
  end
  
  it "should remove leading rank from the name" do
    @taxon.name = "Gen Pseudacris"
    @taxon.save
    expect(@taxon.name).to eq 'Pseudacris'
  end
  
  it "should remove internal 'var' from name" do
    @taxon.name = "Quercus agrifolia var. agrifolia"
    @taxon.save
    expect(@taxon.name).to eq 'Quercus agrifolia agrifolia'
  end
  
  it "should remove internal 'ssp' from name" do
    @taxon.name = "Quercus agrifolia ssp. agrifolia"
    @taxon.save
    expect(@taxon.name).to eq 'Quercus agrifolia agrifolia'
  end
  
  it "should remove internal 'subsp' from name" do
    @taxon.name = "Quercus agrifolia subsp. agrifolia"
    @taxon.save
    expect(@taxon.name).to eq 'Quercus agrifolia agrifolia'
  end

  it "should create TaxonAncestors" do
    t = Taxon.make!( rank: Taxon::SPECIES, parent: @Calypte )
    t.reload
    expect( t.taxon_ancestors ).not_to be_blank
  end
end

describe Taxon, "updating" do
  before(:each) { enable_elastic_indexing( Observation, Taxon ) }
  after(:each) { disable_elastic_indexing( Observation, Taxon ) }
  before(:each) do
    load_test_taxa
  end
  
  it "should update the ancestry col of all associated listed_taxa"
  
  it "should not destroy photos that have observations" do
    t = Taxon.make!
    o = Observation.make!
    p = Photo.make!
    t.photos << p
    make_observation_photo( observation: o, photo: p )
    t.photos = [Photo.make!]
    o.reload
    expect(o.photos).not_to be_blank
  end
end

describe Taxon, "destruction" do
  before(:each) { enable_elastic_indexing( Observation, Taxon ) }
  after(:each) { disable_elastic_indexing( Observation, Taxon ) }
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
    jobs = Delayed::Job.where("created_at >= ?", stamp)
    expect(jobs.select{|j| j.handler =~ /apply_orphan_strategy/m}).not_to be_blank
  end
end

describe Taxon, "orphan descendant destruction" do
  before(:each) { enable_elastic_indexing( Observation, Taxon ) }
  after(:each) { disable_elastic_indexing( Observation, Taxon ) }
  before(:each) do
    load_test_taxa
  end
  
  it "should work" do
    child_ancestry_was = @Apodiformes.child_ancestry
    @Apodiformes.update_attributes(:parent => nil)
    Taxon.update_descendants_with_new_ancestry(@Apodiformes.id, child_ancestry_was)
    expect(@Apodiformes.descendants).to include(@Calypte_anna)
    child_ancestry_was = @Apodiformes.child_ancestry
    @Apodiformes.destroy
    Taxon.apply_orphan_strategy(child_ancestry_was)
    expect(Taxon.find_by_id(@Calypte_anna.id)).to be_blank
  end
end

describe Taxon, "making iconic" do
  before(:each) do
    load_test_taxa
  end
  
  it "should set the iconic taxa of descendant taxa to this taxon" do
    expect(@Calypte_anna.iconic_taxon_id).to be(@Aves.id)
    @Apodiformes.update_attributes(:is_iconic => true)
    @Calypte_anna.reload
    expect(@Calypte_anna.iconic_taxon_id).to be(@Apodiformes.id)
  end
  
  it "should queue a job to change the iconic taxon of descendent observations" do
    expect {
      @Apodiformes.update_attributes(:is_iconic => true)
    }.to change(Delayed::Job, :count).by_at_least(1)
  end
  
  it "should NOT set the iconic taxa of descendant taxa if they descend from a lower iconic taxon" do
    expect(@Aves).to be_is_iconic
    expect(@Chordata).not_to be_is_iconic
    expect(@Calypte_anna.iconic_taxon_id).to be(@Aves.id)
    @Chordata.update_attributes(:is_iconic => true)
    @Calypte_anna.reload
    expect(@Calypte_anna.iconic_taxon_id).to be(@Aves.id)
  end
end

describe "Updating iconic taxon" do
  before(:each) do
    load_test_taxa
  end
  
  it "should set the iconic taxa of descendant taxa" do
    expect(@Calypte_anna.iconic_taxon_id).to be(@Aves.id)
    @Calypte.update_attributes(:iconic_taxon => @Apodiformes)
    @Calypte_anna.reload
    expect(@Calypte_anna.iconic_taxon_id).to be(@Apodiformes.id)
  end
  
  it "should queue a job to change the iconic taxon of descendent observations" do
    expect {
      @Calypte.update_attributes(:iconic_taxon => @Apodiformes)
    }.to change(Delayed::Job, :count).by_at_least(1)
  end
  
  it "should NOT set the iconic taxa of descendant taxa if they descend from a lower iconic taxon" do
    expect(@Aves).to be_is_iconic
    expect(@Chordata).not_to be_is_iconic
    expect(@Calypte_anna.iconic_taxon_id).to be(@Aves.id)
    @Chordata.update_attributes(:iconic_taxon => @Plantae)
    @Calypte_anna.reload
    expect(@Calypte_anna.iconic_taxon_id).to be(@Aves.id)
  end
end

describe Taxon, "set_iconic_taxon_for_observations_of" do
  before(:each) { enable_elastic_indexing( Observation, Taxon ) }
  after(:each) { disable_elastic_indexing( Observation, Taxon ) }
  before(:each) do
    load_test_taxa
  end
  
  it "should set the iconic taxon for observations of descendant taxa" do
    obs = without_delay { Observation.make!(:taxon => @Calypte_anna) }
    expect(@Calypte_anna.iconic_taxon.name).to eq @Aves.name
    expect(obs.iconic_taxon.name).to eq @Calypte_anna.iconic_taxon.name
    @Calypte.update_attributes(:iconic_taxon => @Amphibia)
    expect(@Calypte.iconic_taxon.name).to eq @Amphibia.name
    @Calypte_anna.reload
    expect(@Calypte_anna.iconic_taxon.name).to eq @Amphibia.name
    Taxon.set_iconic_taxon_for_observations_of(@Calypte)
    obs.reload
    expect(obs.iconic_taxon.name).to eq @Amphibia.name
  end

  it "should not change the iconc taxon for observations of other taxa" do
    bird_obs = Observation.make!(:taxon => @Calypte_anna)
    frog_obs = Observation.make!(:taxon => @Pseudacris_regilla)
    expect(bird_obs.iconic_taxon).to eq @Aves
    expect(frog_obs.iconic_taxon).to eq @Amphibia
    @Pseudacris.update_attributes(:iconic_taxon => @Plantae)
    Taxon.set_iconic_taxon_for_observations_of(@Pseudacris)
    frog_obs.reload
    expect(frog_obs.iconic_taxon).to eq @Plantae
    bird_obs.reload
    expect(bird_obs.iconic_taxon).to eq @Aves
  end
  
  it "should NOT set the iconic taxa of observations of descendant taxa if they descend from a lower iconic taxon" do
    expect(@Aves).to be_is_iconic
    expect(@Chordata).not_to be_is_iconic
    expect(@Calypte_anna.iconic_taxon_id).to be(@Aves.id)
    expect(@Calypte_anna.ancestor_ids).to include(@Aves.id)
    expect(@Calypte_anna.ancestor_ids).to include(@Chordata.id)
    obs = Observation.make!(:taxon => @Calypte_anna)
    expect(obs.iconic_taxon).to eq @Aves
    @Chordata.update_attributes(:iconic_taxon => @Plantae)
    Taxon.set_iconic_taxon_for_observations_of(@Chordata)
    @Calypte_anna.reload
    expect(@Calypte_anna.iconic_taxon).to eq @Aves
    obs.reload
    expect(obs.iconic_taxon).to eq @Aves
  end
end

describe Taxon, "normalize_rank" do
  it "should normalize weird ranks" do
    expect(Taxon.normalize_rank('sp')).to eq 'species'
    expect(Taxon.normalize_rank('ssp')).to eq 'subspecies'
    expect(Taxon.normalize_rank('Gen')).to eq 'genus'
  end
  
  it "should normalize ranks with punctuation" do
    expect(Taxon.normalize_rank('super-order')).to eq 'superorder'
  end
end

describe Taxon, "unique name" do

  it "should be the default_name by default" do
    taxon = Taxon.make!(:name => "I am galactus")
    expect(taxon.unique_name).to eq taxon.default_name.name.downcase
  end
  
  it "should be the scientific name if the common name is already another taxon's unique name" do
    taxon = Taxon.make!
    common_name = TaxonName.make!(:name => "Most Awesome Radicalbird", 
      :taxon => taxon, 
      :lexicon => TaxonName::LEXICONS[:ENGLISH])
    taxon.save
    taxon.reload
    expect(taxon.unique_name).to eq taxon.common_name.name.downcase
    
    new_taxon = Taxon.make!(:name => "Ballywickia purhiensis", 
      :rank => 'species')
    new_taxon.taxon_names << TaxonName.make!(
      :name => taxon.common_name.name, 
      :lexicon => TaxonName::LEXICONS[:ENGLISH]
    )
    new_taxon.reload
    expect(new_taxon.unique_name).to eq new_taxon.name.downcase
  end
  
  it "should be nil if all else fails" do
    taxon = Taxon.make! # unique name should be the common name
    common_name = TaxonName.make!(
      :taxon => taxon, 
      :lexicon => TaxonName::LEXICONS[:ENGLISH])
    
    other_taxon = new_taxon = Taxon.make!(:name => taxon.name) # unique name should be the sciname
    new_taxon = Taxon.make!(:name => taxon.name)
    new_common_name = TaxonName.make!(:name => common_name.name,
      :taxon => new_taxon, 
      :lexicon => TaxonName::LEXICONS[:ENGLISH])
    
    new_taxon.reload
    new_taxon.taxon_names.each do |tn|
      puts "#{tn} was invalid: " + tn.errors.full_messages.join(', ') unless tn.valid?
    end
    puts "new_taxon was invalid: " + new_taxon.errors.full_messages.join(', ') unless new_taxon.valid?
    expect(new_taxon.unique_name).to be_nil
  end
  
  it "should work if there are synonyms in different lexicons" do
    taxon = Taxon.make!
    name1 = TaxonName.make!(:taxon => taxon, :name => "foo", :lexicon => TaxonName::LEXICONS[:ENGLISH])
    name2 = TaxonName.make!(:taxon => taxon, :name => "Foo", :lexicon => TaxonName::LEXICONS[:SPANISH])
    taxon.reload
    expect(taxon.unique_name).not_to be_blank
    expect(taxon.unique_name).to eq "foo"
  end
  
  it "should not contain punctuation" do
    taxon = Taxon.make!
    TaxonName.make!(:taxon => taxon, :name => "St. Gerome's Radical Snake", :lexicon => TaxonName::LEXICONS[:ENGLISH])
    taxon.reload
    expect(taxon.unique_name).not_to match(/[\.\'\?\!\\\/]/)
  end
end

describe Taxon, "common_name" do
  it "should default to English if present" do
    t = Taxon.make!
    tn_en = TaxonName.make!(:taxon => t, :name => "Red Devil", :lexicon => TaxonName::LEXICONS[:ENGLISH])
    tn_es = TaxonName.make!(:taxon => t, :name => "Diablo Rojo", :lexicon => TaxonName::LEXICONS[:SPANISH])
    tn_un = TaxonName.make!(:taxon => t, :name => "run away!", :lexicon => 'unspecified')
    expect(t.common_name).to eq(tn_en)
  end
  it "should default to unknown if no English" do
    t = Taxon.make!
    tn_es = TaxonName.make!(:taxon => t, :name => "Diablo Rojo", :lexicon => TaxonName::LEXICONS[:SPANISH])
    tn_un = TaxonName.make!(:taxon => t, :name => "run away!", :lexicon => 'unspecified')
    expect(t.common_name).to eq(tn_un)
  end
  it "should not default to first common if no English or unknown" do
    t = Taxon.make!
    tn_es = TaxonName.make!(:taxon => t, :name => "Diablo Rojo", :lexicon => TaxonName::LEXICONS[:SPANISH])
    expect(t.common_name).to be_blank
  end
end

describe Taxon, "tags_to_taxa" do
  
  before(:each) do
    load_test_taxa
  end
  
  it "should find Animalia and Mollusca" do
    taxa = Taxon.tags_to_taxa(['Animalia', 'Aves'])
    expect(taxa).to include(@Animalia)
    expect(taxa).to include(@Aves)
  end
  
  it "should work on taxonomic machine tags" do
    taxa = Taxon.tags_to_taxa(['taxonomy:kingdom=Animalia', 'taxonomy:class=Aves', 'taxonomy:binomial=Calypte anna'])
    expect(taxa).to include(@Animalia)
    expect(taxa).to include(@Aves)
    expect(taxa).to include(@Calypte_anna)
  end

  it "should not find inactive taxa" do
    active_taxon = Taxon.make!
    inactive_taxon = Taxon.make!(:name => active_taxon.name, :is_active => false)
    taxa = Taxon.tags_to_taxa([active_taxon.name])
    expect(taxa).to include(active_taxon)
    expect(taxa).not_to include(inactive_taxon)
  end

  it "should work for sp" do
    taxa = Taxon.tags_to_taxa(['Calypte sp'])
    expect(taxa).to include(@Calypte)
  end

  it "should work for sp." do
    taxa = Taxon.tags_to_taxa(['Calypte sp.'])
    expect(taxa).to include(@Calypte)
  end

  it "should not strip out sp from Spizella" do
    t = Taxon.make!(:name => 'Spizella')
    taxa = Taxon.tags_to_taxa(['Spizella'])
    expect(taxa).to include(t)
  end

  it "should choose names before codes" do
    code_name = TaxonName.make!(:name => "HOME", :lexicon => "AOU Codes")
    name_name = TaxonName.make!(:name => "Golden-crowned Sparrow", :lexicon => "AOU Codes")
    taxa = Taxon.tags_to_taxa([code_name.name, name_name.name])
    expect(taxa.first).to eq name_name.taxon
  end

  it "should not match a code if it's not an exact match" do
    code_name = TaxonName.make!(:name => "HOME", :lexicon => "AOU Codes")
    taxa = Taxon.tags_to_taxa([code_name.name.downcase])
    expect(taxa).to be_blank
  end

  it "should favor longer names" do
    short_name = TaxonName.make!(:name => "bork", :lexicon => "English")
    long_name = TaxonName.make!(:name => "Giant Dour-Crested Mopple Hopper", :lexicon => "English")
    taxa = Taxon.tags_to_taxa([short_name.name, long_name.name])
    expect(taxa.first).to eq long_name.taxon
  end

  it "should work there are inexact matches" do
    t = Taxon.make!
    TaxonName.make!(:name => "Nutria", :taxon => t, :lexicon => "English")
    TaxonName.make!(:name => "nutria", :taxon => t, :lexicon => "French")
    expect(Taxon.tags_to_taxa(%w(Nutria))).to include t
  end

  it "should not match problematic names" do
    Taxon::PROBLEM_NAMES.each do |name|
      t = Taxon.make!(:name => name.capitalize)
      expect(Taxon.tags_to_taxa([name, name.capitalize])).to be_blank
    end
  end

end

describe Taxon, "merging" do

  before(:each) { enable_elastic_indexing( Observation, Taxon ) }
  after(:each) { disable_elastic_indexing( Observation, Taxon ) }
  
  before(:each) do
    load_test_taxa
    @keeper = Taxon.make!(
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
    expect(rejected_children).not_to be_empty
    keeper.merge(reject)
    rejected_children.each do |child|
      child.reload
      expect(child.parent_id).to be(keeper.parent_id)
    end
  end
  
  it "should move the reject's taxon_names to the keeper" do
    rejected_taxon_names = @reject.taxon_names
    expect(rejected_taxon_names).not_to be_empty
    @keeper.merge(@reject)
    rejected_taxon_names.each do |taxon_name|
      taxon_name.reload
      expect(taxon_name.taxon_id).to be(@keeper.id)
    end
  end
  
  it "should move the reject's taxon_names to the keeper even if they don't have a lexicon" do
    @reject.taxon_names << TaxonName.new(:name => "something")
    rejected_taxon_names = @reject.taxon_names
    expect(rejected_taxon_names).not_to be_empty
    @keeper.merge(@reject)
    rejected_taxon_names.each do |taxon_name|
      taxon_name.reload
      expect(taxon_name.taxon_id).to be(@keeper.id)
    end
  end
  
  it "should move the reject's observations to the keeper" do
    2.times do
      Observation.make!(:taxon => @reject)
    end
    rejected_observations = @reject.observations.all
    expect(rejected_observations).not_to be_empty
    @keeper.merge(@reject)
    rejected_observations.each do |observation|
      observation.reload
      expect(observation.taxon_id).to be(@keeper.id)
    end
  end
  
  it "should move the reject's listed_taxa to the keeper" do
    3.times do
      ListedTaxon.make!(:taxon => @reject)
    end
    rejected_listed_taxa = @reject.listed_taxa.all
    expect(rejected_listed_taxa).not_to be_empty
    @keeper.merge(@reject)
    rejected_listed_taxa.each do |listed_taxon|
      listed_taxon.reload
      expect(listed_taxon.taxon_id).to be(@keeper.id)
    end
  end
  
  it "should move the reject's list_rules to the keeper" do
    rule = ListRule.make!(:operand => @Amphibia, :operator => "in_taxon?")
    reject = rule.operand
    keeper = Taxon.make
    keeper.name = "Amphibia2"
    keeper.unique_name = "Amphibia2"
    keeper.save
    keeper.update_attributes(:parent => reject.parent)
    
    keeper.merge(reject)
    rule.reload
    expect(rule.operand_id).to be(keeper.id)
  end
  
  it "should move the reject's identifications to the keeper" do
    3.times do
      Identification.make!(:taxon => @reject)
    end
    rejected_identifications = @reject.identifications.all
    expect(rejected_identifications).not_to be_empty
    @keeper.merge(@reject)
    rejected_identifications.each do |identification|
      identification.reload
      expect(identification.taxon_id).to be(@keeper.id)
    end
  end
  
  it "should move the reject's taxon_links to the keeper" do
    3.times do
      TaxonLink.make!(:taxon => @reject)
    end
    rejected_taxon_links = @reject.taxon_links.all
    expect(rejected_taxon_links).not_to be_empty
    @keeper.merge(@reject)
    rejected_taxon_links.each do |taxon_link|
      taxon_link.reload
      expect(taxon_link.taxon_id).to be(@keeper.id)
    end
  end
  
  it "should move the reject's taxon_photos to the keeper" do
    3.times do
      TaxonPhoto.make!(:taxon => @reject)
    end
    rejected_taxon_photos = @reject.taxon_photos.all
    expect(rejected_taxon_photos).not_to be_empty
    @keeper.merge(@reject)
    rejected_taxon_photos.each do |taxon_photo|
      taxon_photo.reload
      expect(taxon_photo.taxon_id).to be(@keeper.id)
    end
  end
  
  it "should move the reject's colors to the keeper"
  
  it "should mark scinames not matching the keeper as invalid" do
    old_sciname = @reject.scientific_name
    expect(old_sciname).to be_is_valid
    @keeper.merge(@reject)
    old_sciname.reload
    expect(old_sciname).not_to be_is_valid
  end
  
  it "should delete duplicate taxon_names from the reject" do
    old_sciname = @reject.scientific_name
    @keeper.taxon_names << old_sciname.dup
    @keeper.merge(@reject)
    expect(TaxonName.find_by_id(old_sciname.id)).to be_nil
  end
  
  it "should delete listed_taxa from the reject that are invalid"
  
  it "should destroy the reject" do
    @keeper.merge(@reject)
    expect(Taxon.find_by_id(@reject.id)).to be_nil
  end
  
  it "should not create duplicate listed taxa" do
    lt1 = ListedTaxon.make!(:taxon => @keeper)
    lt2 = ListedTaxon.make!(:taxon => @reject, :list => lt1.list)
    @keeper.merge(@reject)
    expect(lt1.list.listed_taxa.where(taxon_id: @keeper.id).count).to eq 1
  end
  
  it "should set iconic taxa on children" do
    reject = Taxon.make!
    child = Taxon.make!(:parent => reject)
    expect(child.iconic_taxon_id).not_to eq @keeper.iconic_taxon_id
    expect(child.iconic_taxon_id).to eq reject.iconic_taxon_id
    @keeper.merge(reject)
    child.reload
    expect(child.iconic_taxon_id).to eq @keeper.iconic_taxon_id
  end
  
  it "should set iconic taxa on descendants" do
    expect(@Calypte_anna.iconic_taxon_id).not_to eq @Pseudacris.iconic_taxon_id
    @Pseudacris.merge(@Calypte)
    @Calypte_anna.reload
    expect(@Calypte_anna.iconic_taxon_id).to eq @Pseudacris.iconic_taxon_id
  end
  
  it "should queue a job to set iconic taxon on observations of descendants" do
    Delayed::Job.delete_all
    stamp = Time.now
    @Pseudacris.merge(@Calypte)
    jobs = Delayed::Job.where("created_at >= ?", stamp)
    expect(jobs.select{|j| j.handler =~ /set_iconic_taxon_for_observations_of/m}).not_to be_blank
  end
  
  it "should delete invalid flags" do
    u = User.make!
    @keeper.flags.create(:user => u, :flag => "foo")
    @reject.flags.create(:user => u, :flag => "foo")
    @keeper.merge(@reject)
    @keeper.reload
    expect(@keeper.flags.size).to eq(1)
  end

  it "should remove duplicate schemes" do
    ts = TaxonScheme.make!
    t1 = Taxon.make!
    t1.taxon_schemes << ts
    t2 = Taxon.make!
    t2.taxon_schemes << ts
    t1.merge(t2)
    t1.reload
    expect(t1.taxon_schemes.size).to eq(1)
  end

  it "should set iconic taxon for observations of reject" do
    reject = Taxon.make!
    o = without_delay {Observation.make!(:taxon => reject)}
    expect(o.iconic_taxon).to be_blank
    without_delay {@keeper.merge(reject)}
    o.reload
    expect(o.iconic_taxon).to eq(@keeper.iconic_taxon)
  end

  it "should update subscriptions" do
    s = Subscription.make!(:resource => @reject)
    @keeper.merge(@reject)
    s.reload
    expect(s.resource).to eq @keeper
  end

  it "should not alter with subscriptions to other classess" do
    reject = Taxon.make!(:id => 888)
    keeper = Taxon.make!(:id => 999)
    o = Observation.make!(:id => 888)
    s = Subscription.make!(:resource => o)
    keeper.merge(reject)
    s.reload
    expect(s.resource).to eq(o)
  end

  it "should work with denormalized ancestries" do
    AncestryDenormalizer.truncate
    expect(TaxonAncestor.count).to eq 0
    AncestryDenormalizer.denormalize
    expect {
      @keeper.merge(@reject)
    }.not_to raise_error
  end
end

describe Taxon, "moving" do

  before(:each) { enable_elastic_indexing( Observation, Taxon, Identification ) }
  after(:each) { disable_elastic_indexing( Observation, Taxon, Identification ) }
  
  before(:each) do
    load_test_taxa
  end
  
  it "should update the iconic taxon of observations" do
    obs = Observation.make!(:taxon => @Calypte_anna)
    old_iconic_id = obs.iconic_taxon_id
    taxon = obs.taxon
    taxon.move_to_child_of(@Amphibia)
    taxon.reload
    obs.reload
    expect(obs.iconic_taxon_id).not_to be(old_iconic_id)
    expect(obs.iconic_taxon_id).to be(taxon.iconic_taxon_id)
  end
  
  it "should queue a job to set iconic taxon on observations of descendants" do
    obs = without_delay { Observation.make!(:taxon => @Calypte_anna) }
    old_iconic_id = obs.iconic_taxon_id
    taxon = obs.taxon
    Delayed::Job.delete_all
    stamp = Time.now
    taxon.parent.move_to_child_of(@Amphibia)
    jobs = Delayed::Job.where("created_at >= ?", stamp)
    expect(jobs.select{|j| j.handler =~ /set_iconic_taxon_for_observations_of/m}).not_to be_blank
  end

  it "should set iconic taxon on observations of descendants" do
    obs = without_delay { Observation.make!(:taxon => @Calypte_anna) }
    old_iconic_id = obs.iconic_taxon_id
    taxon = obs.taxon
    without_delay do
      taxon.parent.move_to_child_of(@Amphibia)
    end
    obs.reload
    expect(obs.iconic_taxon).to eq(@Amphibia)
  end

  it "should set iconic taxon on observations of descendants if grafting for the first time" do
    parent = Taxon.make!
    taxon = Taxon.make!(:parent => parent)
    obs = without_delay { Observation.make!(:taxon => taxon) }
    expect(obs.iconic_taxon).to be_blank
    without_delay do
      parent.move_to_child_of(@Amphibia)
    end
    obs.reload
    expect(obs.iconic_taxon).to eq(@Amphibia)
  end
  
  it "should not raise an exception if the new parent doesn't exist" do
    taxon = Taxon.make!
    bad_id = Taxon.last.id + 1
    expect {
      taxon.parent_id = bad_id
    }.not_to raise_error
  end
  
  # this is something we override from the ancestry gem
  it "should queue a job to update descendant ancetries" do
    Delayed::Job.delete_all
    stamp = Time.now
    @Calypte.update_attributes(:parent => @Hylidae)
    jobs = Delayed::Job.where("created_at >= ?", stamp)
    expect(jobs.select{|j| j.handler =~ /update_descendants_with_new_ancestry/m}).not_to be_blank
  end

  it "should not queue a job to update descendant ancetries if skip_after_move set" do
    Delayed::Job.delete_all
    stamp = Time.now
    @Calypte.update_attributes(:parent => @Hylidae, :skip_after_move => true)
    jobs = Delayed::Job.where("created_at >= ?", stamp)
    expect(jobs.select{|j| j.handler =~ /update_descendants_with_new_ancestry/m}).not_to be_blank
  end

  it "should queue a job to update observation stats if there are observations" do
    Delayed::Job.delete_all
    stamp = Time.now
    o = Observation.make!( taxon: @Calypte )
    expect( Observation.of( @Calypte ).count ).to eq 1
    @Calypte.update_attributes( parent: @Hylidae )
    jobs = Delayed::Job.where( "created_at >= ?", stamp )
    expect( jobs.select{|j| j.handler =~ /update_stats_for_observations_of/m} ).not_to be_blank
  end

  it "should not queue a job to update observation stats if there are no observations" do
    Delayed::Job.delete_all
    stamp = Time.now
    expect(Observation.of(@Calypte).count).to eq(0)
    @Calypte.update_attributes(:parent => @Hylidae)
    jobs = Delayed::Job.where("created_at >= ?", stamp)
    expect(jobs.select{|j| j.handler =~ /update_stats_for_observations_of/m}).to be_blank
  end

  it "should update community taxa" do
    fam = Taxon.make!(:rank => "family")
    subfam = Taxon.make!(:rank => "subfamily", :parent => fam)
    gen = Taxon.make!(:rank => "genus", :parent => fam)
    sp = Taxon.make!(:rank => "species", :parent => gen)
    o = Observation.make!
    i1 = Identification.make!(:observation => o, :taxon => subfam)
    i2 = Identification.make!(:observation => o, :taxon => sp)
    expect(Identification.of(gen).exists?).to be true
    o.reload
    expect(o.taxon).to eq fam
    Delayed::Worker.new.work_off
    without_delay do
      gen.update_attributes(:parent => subfam)
    end
    o.reload
    expect(o.taxon).to eq subfam
  end

  it "should create TaxonAncestors" do
    t = Taxon.make!( rank: Taxon::SPECIES, name: "Ronica vestrit" )
    expect( t.taxon_ancestors.count ).to eq 1 # should always make one for itself
    t.move_to_child_of( @Calypte )
    t.reload
    expect( t.taxon_ancestors.count ).to be > 1
    expect( t.taxon_ancestors.detect{ |ta| ta.ancestor_taxon_id == @Calypte.id } ).not_to be_blank
  end

  it "should remove existing TaxonAncestors" do
    t = Taxon.make!( rank: Taxon::SPECIES, parent: @Calypte )
    expect( TaxonAncestor.where( taxon_id: t.id, ancestor_taxon_id: @Calypte.id ).count ).to eq 1
    t.move_to_child_of( @Pseudacris )
    expect( TaxonAncestor.where( taxon_id: t.id, ancestor_taxon_id: @Calypte.id ).count ).to eq 0
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
    expect(@Calypte_anna.ancestry).to be =~ /^#{@Hylidae.ancestry}/
    expect(@Calypte_anna.ancestry).to be =~ /^#{@Calypte.ancestry}/
  end
end

describe Taxon do
  describe "featuring" do
    it "should fail if no photos" do
      taxon = Taxon.make!
      taxon.featured_at = Time.now
      expect(taxon.photos).to be_blank
      taxon.valid?
      expect(taxon.errors[:featured_at]).not_to be_blank
    end
  end
  
  describe "conservation status" do
    it "should define boolean methods" do
      taxon = Taxon.make!(:conservation_status => Taxon::IUCN_VULNERABLE)
      expect(taxon).to be_iucn_vulnerable
      expect(taxon).not_to be_iucn_extinct
    end
  end
  
  describe "locking" do
    it "should cause grafting descendents to fail" do
      taxon = Taxon.make!(:locked => true)
      child = Taxon.make!
      expect(child.parent).not_to be(taxon)
      child.update_attribute(:parent, taxon)
      expect(child.parent).not_to be(taxon)
    end
    
    it "should prevent new scientific taxon names of descendents"
  end
end


describe Taxon, "grafting" do
  before(:each) { enable_elastic_indexing( Observation, Taxon ) }
  after(:each) { disable_elastic_indexing( Observation, Taxon ) }
  before(:each) do
    load_test_taxa
    @graftee = Taxon.make!(:rank => "species")
  end
  
  it "should set iconic taxa on children" do
    expect(@graftee.iconic_taxon_id).not_to eq @Pseudacris.iconic_taxon_id
    @graftee.update_attributes(:parent => @Pseudacris)
    @graftee.reload
    expect(@graftee.iconic_taxon_id).to eq @Pseudacris.iconic_taxon_id
  end
  
  it "should set iconic taxa on descendants" do
    taxon = Taxon.make!(:name => "Craptaculous", :parent => @graftee)
    @graftee.update_attributes(:parent => @Pseudacris)
    taxon.reload
    expect(taxon.iconic_taxon_id).to eq @Pseudacris.iconic_taxon_id
  end
  
  it "should queue a job to set iconic taxon on observations of descendants" do
    Delayed::Job.delete_all
    stamp = Time.now
    @graftee.update_attributes(:parent => @Pseudacris)
    jobs = Delayed::Job.where("created_at >= ?", stamp)
    expect(jobs.select{|j| j.handler =~ /set_iconic_taxon_for_observations_of/m}).not_to be_blank
  end

  it "should set the parent of a species based on the polynom genus" do
    t = Taxon.make!(:name => "Pseudacris foo")
    t.graft
    expect(t.parent).to eq(@Pseudacris)
  end

  describe "indexing" do
    before(:each) { enable_elastic_indexing( Identification ) }
    after(:each) { disable_elastic_indexing( Identification ) }
    before(:all) { DatabaseCleaner.strategy = :truncation }
    after(:all)  { DatabaseCleaner.strategy = :transaction }

    it "should re-index identifications in the observations index" do
      o = make_research_grade_candidate_observation
      3.times { Identification.make!( observation: o, taxon: @Pseudacris ) }
      i = Identification.make!( observation: o )
      i.reload
      expect( i.taxon ).not_to be_grafted
      expect( i.category ).to eq Identification::MAVERICK
      es_o_idents = Observation.elastic_search( where: { id: o.id } ).results.results[0].identifications.sort_by(&:id)
      expect( es_o_idents[0].category ).to eq Identification::IMPROVING
      expect( es_o_idents[1].category ).to eq Identification::SUPPORTING
      expect( es_o_idents[2].category ).to eq Identification::SUPPORTING
      expect( es_o_idents[3].category ).to eq Identification::MAVERICK
      without_delay { i.taxon.update_attributes( parent: @Pseudacris ) }
      i.reload
      expect( i.taxon.ancestor_ids ).to include( @Pseudacris.id)
      expect( i.category ).to eq Identification::LEADING
      es_o_idents = Observation.elastic_search( where: { id: o.id } ).results.results[0].identifications.sort_by(&:id)
      expect( es_o_idents[0].category ).to eq Identification::IMPROVING
      expect( es_o_idents[1].category ).to eq Identification::SUPPORTING
      expect( es_o_idents[2].category ).to eq Identification::SUPPORTING
      expect( es_o_idents[3].category ).to eq Identification::LEADING
    end
  end
end

describe Taxon, "single_taxon_for_name" do
  it "should find varieties" do
    name = "Abies magnifica var. magnifica"
    t = Taxon.make!(:name => name, :rank => Taxon::VARIETY)
    expect(t).to be_variety
    expect(t.name).to eq("Abies magnifica magnifica")
    expect(Taxon.single_taxon_for_name(name)).to eq(t)
  end

  it "should not choke on parens" do
    t = Taxon.make!(:name => "Foo")
    expect {
      expect(Taxon.single_taxon_for_name("(Foo")).to eq(t)
    }.not_to raise_error
  end

  it "should find a valid name, not invalid synonyms within the same parent" do
    name = "Foo bar"
    parent = Taxon.make!
    valid = Taxon.make!(:name => name, :parent => parent)
    invalid = Taxon.make!(:parent => parent)
    invalid.taxon_names.create(:name => name, :is_valid => false, :lexicon => TaxonName::SCIENTIFIC_NAMES)
    expect(Taxon.single_taxon_for_name(name)).to eq(valid)
  end

  it "should find a single valid name among invalid synonyms" do
    valid = Taxon.make!(:parent => Taxon.make!)
    invalid = Taxon.make!(:parent => Taxon.make!)
    tn = TaxonName.create!(taxon: invalid, name: valid.name, is_valid: false, lexicon: TaxonName::SCIENTIFIC_NAMES)
    all_names = [valid.taxon_names.map(&:name), invalid.reload.taxon_names.map(&:name)].flatten.uniq
    expect( all_names.size ).to eq 2
    expect( tn.is_valid? ).to eq false
    expect(Taxon.single_taxon_for_name(valid.name)).to eq(valid)
  end
end

describe Taxon, "update_life_lists" do
  it "should not queue jobs if they already exist" do
    t = Taxon.make!
    l = make_life_list_for_taxon(t)
    Delayed::Job.delete_all
    expect {
      2.times do
        t.update_life_lists
      end
    }.to change(Delayed::Job, :count).by(1)
  end
end

describe Taxon, "threatened?" do
  before(:each) { enable_elastic_indexing( Observation, Taxon ) }
  after(:each) { disable_elastic_indexing( Observation, Taxon ) }
  it "should work for a place"
  it "should work for lat/lon" do
    p = make_place_with_geom
    cs = ConservationStatus.make!(:place => p)
    expect(p.contains_lat_lng?(p.latitude, p.longitude)).to be true
    t = cs.taxon
    expect(t.threatened?(:latitude => p.latitude, :longitude => p.longitude)).to be true
  end
end

describe Taxon, "geoprivacy" do
  before(:each) { enable_elastic_indexing( Observation, Taxon ) }
  after(:each) { disable_elastic_indexing( Observation, Taxon ) }
  it "should choose the maximum privacy relevant to the location" do
    t = Taxon.make!(:rank => Taxon::SPECIES)
    p = make_place_with_geom
    cs_place = ConservationStatus.make!(:taxon => t, :place => p, :geoprivacy => Observation::PRIVATE)
    cs_global = ConservationStatus.make!(:taxon => t)
    expect( t.geoprivacy(latitude: p.latitude, longitude: p.longitude) ).to eq Observation::PRIVATE
  end

  it "should be blank if conservation statuses exist but all are open" do
    t = Taxon.make!(rank: Taxon::SPECIES)
    p = make_place_with_geom
    cs_place = ConservationStatus.make!(taxon: t, place: p, geoprivacy: Observation::OPEN)
    cs_global = ConservationStatus.make!(taxon: t, geoprivacy: Observation::OPEN)
    expect( t.geoprivacy(latitude: p.latitude, longitude: p.longitude) ).to be_blank
  end
end

describe Taxon, "max_geoprivacy" do
  let(:t1) { Taxon.make!(rank: Taxon::SPECIES) }
  let(:t2) { Taxon.make!(rank: Taxon::SPECIES) }
  let(:taxon_ids) { [t1.id, t2.id] }
  it "should be private if one of the taxa has a private global status" do
    cs_global = ConservationStatus.make!( taxon: t1, geoprivacy: Observation::PRIVATE )
    expect( Taxon.max_geoprivacy( taxon_ids ) ).to eq Observation::PRIVATE
  end
  it "should be private if one of the ancestor taxa has a private global status" do
    parent = Taxon.make!( rank: Taxon::GENUS )
    cs_global = ConservationStatus.make!( taxon: parent, geoprivacy: Observation::PRIVATE )
    without_delay do
      t1.update_attributes( parent: parent )
    end
    expect( t1.ancestor_ids ).to include parent.id
    expect( Taxon.max_geoprivacy( taxon_ids ) ).to eq Observation::PRIVATE
  end
  it "should be nil if one none of the taxa have global status" do
    expect( Taxon.max_geoprivacy( taxon_ids ) ).to eq nil
  end
end

describe Taxon, "to_styled_s" do
  it "should return normal names untouched" do
    expect(Taxon.new(:name => "Tom", :rank => nil).to_styled_s).to eq "Tom"
  end

  it "should italicize genera and below" do
    expect(Taxon.new(:name => "Tom", :rank => "genus").to_styled_s).to eq "Genus <i>Tom</i>"
    expect(Taxon.new(:name => "Tom", :rank => "species").to_styled_s).to eq "<i>Tom</i>"
    expect(Taxon.new(:name => "Tom", :rank => "infraspecies").to_styled_s).to eq "<i>Tom</i>"
  end

  it "should add ranks to genera and above" do
    expect(Taxon.new(:name => "Tom", :rank => "genus").to_styled_s).to eq "Genus <i>Tom</i>"
    expect(Taxon.new(:name => "Tom", :rank => "family").to_styled_s).to eq "Family Tom"
    expect(Taxon.new(:name => "Tom", :rank => "kingdom").to_styled_s).to eq "Kingdom Tom"
  end

  it "should add common name when available" do
    taxon = Taxon.new(:name => "Tom", :rank => "genus")
    common_name = TaxonName.make!(:name => "Common",
      :taxon => taxon, :lexicon => TaxonName::LEXICONS[:ENGLISH])
    taxon.reload
    expect(taxon.to_styled_s).to eq "Common (Genus <i>Tom</i>)"
  end
end

describe Taxon, "leading_name" do
  it "returns the scientific name if that's all there is" do
    expect(Taxon.make!(name: "Tom").leading_name).to eq "Tom"
  end

  it "returns the common name when available" do
    taxon = Taxon.make!(name: "Tom")
    TaxonName.make!(name: "Common",
      taxon: taxon, lexicon: TaxonName::LEXICONS[:ENGLISH])
    expect(taxon.leading_name).to eq "Common"
  end
end

describe Taxon, "editable_by?" do
  let(:admin) { make_admin }
  let(:curator) { make_curator }
  it "should be editable by admins if class" do
    expect( Taxon.make!( rank: Taxon::CLASS ) ).to be_editable_by( admin )
  end
  it "should be editable by curators if below order" do
    taxon = Taxon.make!( rank: Taxon::FAMILY )
    expect( taxon ).to be_editable_by( curator )
  end
  it "should not be editable by curators if order or above" do
    expect( Taxon.make!( rank: Taxon::CLASS ) ).not_to be_editable_by( curator )
  end
  describe "complete taxa" do
    let(:taxon) { Taxon.make!( rank: Taxon::GENUS, complete: true ) }
    it "should be editable by taxon curators of that taxon" do
      tc = TaxonCurator.make!( taxon: taxon )
      expect( taxon ).to be_editable_by( tc.user )
    end
    it "should not be editable by other site curators" do
      tc = TaxonCurator.make!( taxon: taxon )
      expect( taxon ).not_to be_editable_by( curator )
    end
  end
  describe "descendants of complete taxa" do
    let(:family) { Taxon.make!( rank: Taxon::FAMILY, complete: true ) }
    let(:taxon_curator) { TaxonCurator.make!( taxon: family ) }
    let(:genus) { Taxon.make!( rank: Taxon::GENUS, parent: family, current_user: taxon_curator.user ) }
    it "should be editable by taxon curators of complete taxon" do
      expect( genus ).to be_editable_by( taxon_curator.user )
    end
    it "should not be editable by other site curators" do
      expect( genus ).not_to be_editable_by( curator )
    end
  end
  describe "incomplete descendants of complete taxa" do
    let(:family) { Taxon.make!( rank: Taxon::FAMILY, complete: true, complete_rank: Taxon::GENUS ) }
    let(:taxon_curator) { TaxonCurator.make!( taxon: family ) }
    let(:genus) { Taxon.make!( rank: Taxon::GENUS, parent: family, current_user: taxon_curator.user ) }
    let(:species) { Taxon.make!( rank: Taxon::SPECIES, parent: genus ) }
    it "should be editable by taxon curators of complete taxon" do
      expect( species ).to be_editable_by( taxon_curator.user )
    end
    it "should be editable by other site curators" do
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
    t.taxon_names.update_all(is_valid: false)
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

describe "complete" do
  it "should reindex all descendants when changed" do
    family = Taxon.make!( rank: Taxon::FAMILY )
    genus = Taxon.make!( rank: Taxon::GENUS, parent: family )
    species = Taxon.make!( rank: Taxon::SPECIES, parent: genus )
    Delayed::Worker.new.work_off
    es_genus = Taxon.elastic_search( where: { id: genus.id } ).results.results.first
    expect( es_genus.complete_species_count ).to be_nil
    without_delay { family.update_attributes!( complete: true ) }
    genus.reload
    expect( genus.complete_species_count ).to eq 1
    es_genus = Taxon.elastic_search( where: { id: genus.id } ).results.results.first
    expect( es_genus.complete_species_count ).to eq 1
  end
  it "should destroy TaxonCurators when set to false" do
    t = Taxon.make!( complete: true )
    tc = TaxonCurator.make!( taxon: t )
    t.update_attributes( complete: false )
    expect( TaxonCurator.find_by_id( tc.id ) ).to be_nil
  end
  describe "when current_user" do
    let(:family) { Taxon.make!( rank: Taxon::FAMILY, complete: true ) }
    let(:taxon_curator) { TaxonCurator.make!( taxon: family ) }
    let(:genus) { Taxon.make!( rank: Taxon::GENUS, parent: family, current_user: taxon_curator.user ) }
    let(:species) { Taxon.make!( rank: Taxon::SPECIES, parent: genus, current_user: taxon_curator.user ) }
    describe "is blank" do
      it "should prevent grafting to this taxon" do
        t = Taxon.make( rank: Taxon::GENUS, parent: family )
        expect( t ).not_to be_valid
      end
      it "should prevent grafting to a descendant" do
        t = Taxon.make( rank: Taxon::SPECIES, parent: genus )
        expect( t ).not_to be_valid
      end
      it "should allow grafting to taxa beyond the complete_rank" do
        family.update_attributes( complete_rank: Taxon::GENUS )
        expect( Taxon.make( rank: Taxon::SUBSPECIES, parent: species ) ).to be_valid
      end
    end
    describe "is not a TaxonCurator" do
      let(:current_user) { User.make! }
      it "should prevent grafting to this taxon" do
        t = Taxon.make( rank: Taxon::GENUS, parent: family, current_user: current_user )
        expect( t ).not_to be_valid
      end
      it "should prevent grafting to a descendant" do
        t = Taxon.make( rank: Taxon::SPECIES, parent: genus, current_user: current_user )
        expect( t ).not_to be_valid
      end
      it "should allow grafting to taxa beyond the complete_rank" do
        family.update_attributes( complete_rank: Taxon::GENUS )
        expect( Taxon.make( rank: Taxon::SUBSPECIES, parent: species, current_user: current_user ) ).to be_valid
      end
    end
    describe "is a TaxonCurator" do
      it "should allow grafting to this taxon" do
        t = Taxon.make( rank: Taxon::GENUS, parent: family, current_user: taxon_curator.user )
        expect( t ).to be_valid
      end
      it "should allow grafting to a descendant" do
        t = Taxon.make( rank: Taxon::SPECIES, parent: genus, current_user: taxon_curator.user )
        expect( t ).to be_valid
      end
      it "should allow grafting to taxa beyond the complete_rank" do
        family.update_attributes( complete_rank: Taxon::GENUS )
        expect( Taxon.make( rank: Taxon::SUBSPECIES, parent: species, current_user: taxon_curator.user ) ).to be_valid
      end
    end
  end
end

describe "complete_rank" do
  it "should reindex all descendants when changed" do
    superfamily = Taxon.make!( rank: Taxon::SUPERFAMILY )
    family = Taxon.make!( rank: Taxon::FAMILY, parent: superfamily )
    genus = Taxon.make!( rank: Taxon::GENUS, parent: family )
    species = Taxon.make!( rank: Taxon::SPECIES, parent: genus )
    without_delay { superfamily.update_attributes!( complete: true ) }
    Delayed::Worker.new.work_off
    es_genus = Taxon.elastic_search( where: { id: genus.id } ).results.results.first
    es_family = Taxon.elastic_search( where: { id: family.id } ).results.results.first
    expect( es_genus.complete_species_count ).to eq 1
    without_delay { superfamily.update_attributes!( complete_rank: Taxon::GENUS ) }
    genus.reload
    family.reload
    expect( genus.complete_species_count ).to be_nil
    es_genus = Taxon.elastic_search( where: { id: genus.id } ).results.results.first
    es_family = Taxon.elastic_search( where: { id: family.id } ).results.results.first
    expect( es_genus.complete_species_count ).to be_nil
  end
  it "should not be above the rank of the taxon" do
    t = Taxon.make( rank: Taxon::FAMILY, complete_rank: Taxon::SUPERFAMILY )
    expect( t ).not_to be_valid
  end
  it "should remove TaxonCurators of taxa that are no longer one of the complete descendants" do
    superfamily = Taxon.make!( rank: Taxon::SUPERFAMILY, complete: true )
    taxon_curator = TaxonCurator.make!( taxon: superfamily )
    family = Taxon.make!( rank: Taxon::FAMILY, parent: superfamily, current_user: taxon_curator.user )
    genus = Taxon.make!( rank: Taxon::GENUS, parent: family, current_user: taxon_curator.user )
    tc = TaxonCurator.make!( taxon: genus )
    superfamily.update_attributes( complete_rank: Taxon::FAMILY )
    expect( TaxonCurator.find_by_id( tc.id ) ).to be_nil
  end
end

describe "complete_species_count" do
  describe "when taxon is not complete" do
    it "should be nil if no complete ancestor" do
      t = Taxon.make!
      expect( t.complete_species_count ).to be_nil
    end
    it "should be set if complete ancestor exists" do
      ancestor = Taxon.make!( complete: true, rank: Taxon::FAMILY )
      taxon_curator = TaxonCurator.make!( taxon: ancestor )
      t = Taxon.make!( parent: ancestor, rank: Taxon::GENUS, current_user: taxon_curator.user )
      expect( t.complete_species_count ).not_to be_nil
      expect( t.complete_species_count ).to eq 0
    end
    it "should be nil if complete ancestor exists but it is complete at a higher rank" do
      superfamily = Taxon.make!( complete: true, rank: Taxon::SUPERFAMILY, complete_rank: Taxon::GENUS )
      taxon_curator = TaxonCurator.make!( taxon: superfamily )
      family = Taxon.make!( rank: Taxon::FAMILY, parent: superfamily, current_user: taxon_curator.user )
      genus = Taxon.make!( rank: Taxon::GENUS, parent: family, current_user: taxon_curator.user )
      species = Taxon.make!( rank: Taxon::SPECIES, parent: genus, current_user: taxon_curator.user )
      expect( genus.complete_species_count ).to be_nil
    end
  end
  describe "when taxon is complete" do
    let(:complete_taxon) { Taxon.make!( complete: true, rank: Taxon::FAMILY ) }
    let(:taxon_curator) { TaxonCurator.make!( taxon: complete_taxon ) }
    it "should count species" do
      species = Taxon.make!( rank: Taxon::SPECIES, parent: complete_taxon, current_user: taxon_curator.user )
      expect( complete_taxon.complete_species_count ).to eq 1
    end
    it "should not count genera" do
      genus = Taxon.make!( rank: Taxon::GENUS, parent: complete_taxon, current_user: taxon_curator.user )
      expect( complete_taxon.complete_species_count ).to eq 0
    end
    it "should not count hybrids" do
      hybrid = Taxon.make!( rank: Taxon::HYBRID, parent: complete_taxon, current_user: taxon_curator.user )
      expect( complete_taxon.complete_species_count ).to eq 0
    end
    it "should not count extinct species" do
      extinct_species = Taxon.make!( rank: Taxon::SPECIES, parent: complete_taxon, current_user: taxon_curator.user )
      ConservationStatus.make!( taxon: extinct_species, iucn: Taxon::IUCN_EXTINCT, status: "extinct" )
      extinct_species.reload
      expect( extinct_species.conservation_statuses.first.iucn ).to eq Taxon::IUCN_EXTINCT
      expect( extinct_species.conservation_statuses.first.place ).to be_blank
      expect( complete_taxon.complete_species_count ).to eq 0
    end
    it "should count species with place-specific non-extinct conservation statuses" do
      cs_species = Taxon.make!( rank: Taxon::SPECIES, parent: complete_taxon, current_user: taxon_curator.user )
      ConservationStatus.make!( taxon: cs_species, iucn: Taxon::IUCN_VULNERABLE, status: "VU" )
      cs_species.reload
      expect( cs_species.conservation_statuses.first.iucn ).to eq Taxon::IUCN_VULNERABLE
      expect( cs_species.conservation_statuses.first.place ).to be_blank
      expect( complete_taxon.complete_species_count ).to eq 1
    end
    it "should not count inactive taxa" do
      species = Taxon.make!( rank: Taxon::SPECIES, parent: complete_taxon, is_active: false, current_user: taxon_curator.user )
      expect( complete_taxon.complete_species_count ).to eq 0
    end
  end
end
