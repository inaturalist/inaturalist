require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Identification, "creation" do
  fixtures :users, :taxa, :observations, :lists, :listed_taxa
  before(:each) do
    obs = Observation.create(:species_guess => "Pacific Chorus Frog", 
                          :taxon => taxa(:Pseudacris_regilla),
                          :user => users(:adam))
    @identification = Identification.new(
      :user => users(:quentin),
      :observation => obs,
      :taxon => obs.taxon
    )
    @empty_identification = Identification.new
    @unknown_obs = Observation.create(:species_guess => "You got me!",
                          :user => users(:adam))
  end
  
  it "should return a new instance" do
    @identification.save!
    @identification.should_not be(nil)
    @identification.new_record?.should be(false)
  end
  
  it "should have a taxon" do 
    @empty_identification = Identification.new
    @empty_identification.valid?
    @empty_identification.errors.on(:taxon_id).should_not be(nil)
  end
  
  it "should have a user" do 
    @empty_identification = Identification.new
    @empty_identification.valid?
    @empty_identification.errors.on(:user_id).should_not be(nil)
  end
  
  it "should have an observation" do 
    @empty_identification = Identification.new
    @empty_identification.valid?
    @empty_identification.errors.on(:observation_id).should_not be(nil)
  end
  
  it "should not let you identify the same observation twice" do
    @identification.save
    bad_identification = Identification.new(
      :user => users(:quentin),
      :observation => @identification.observation,
      :taxon => Taxon.find_by_name('Calypte anna')
    )
    bad_identification.valid?
    bad_identification.errors.on(:user_id).should_not be(nil)
  end
  
  it "should add a taxon to its observation if it's the observer's "+
     "identification" do
    @unknown_obs.taxon_id.should be(nil)
    identification = Identification.create(
      :user => @unknown_obs.user,
      :observation => @unknown_obs,
      :taxon => Taxon.find_by_name('Calypte anna')
    )
    @unknown_obs.reload
    @unknown_obs.taxon_id.should == identification.taxon.id
  end
  
  it "should add a species_guess to a newly identified observation if the "+
     "owner identified it and the species_guess was nil" do
    @unknown_obs.species_guess = nil
    @unknown_obs.taxon_id.should be(nil)
    anna = Taxon.find_by_name('Calypte anna')
    identification = Identification.create(
      :user => @unknown_obs.user,
      :observation => @unknown_obs,
      :taxon => anna
    )
    @unknown_obs.reload
    @unknown_obs.species_guess.should == anna.to_plain_s
  end
  
  it "should add an iconic_taxon_id to its observation if it's the observer's identification" do
    @unknown_obs.taxon_id.should be(nil)
    identification = Identification.create(
      :user => @unknown_obs.user,
      :observation => @unknown_obs,
      :taxon => Taxon.find_by_name('Calypte anna')
    )
    @unknown_obs.reload
    @unknown_obs.iconic_taxon_id.should == identification.taxon.iconic_taxon_id
  end
  
  it "should increment the observations num_identification_agreements if this is an agreement" do
    # ted = User.find_by_login('ted')
    jill = users(:jill) # User.find_by_login('ted')
    @identification.observation.user.should_not be(jill)
    @identification.user = jill
    @identification.observation.num_identification_agreements.should == 0
    @identification.save
    @identification.reload
    @identification.is_agreement?.should be(true)
    @identification.observation.num_identification_agreements.should == 1
  end
  
  it "should increment the observations num_identification_disagreements if this is an disagreement" do
    taxon = Taxon.find(:first, :conditions => ["id != ? && rank = 'species'", @identification.observation.taxon])
    user = users(:ted) # User.find_by_login('ted')
    @identification.observation.identifications.select {|i| i.user == user}.each(&:destroy)
    @identification.user = user
    @identification.taxon = taxon
    @identification.user.should_not == @identification.observation.user
    @identification.observation.num_identification_disagreements.should == 0
    @identification.save
    @identification.reload
    @identification.is_agreement?.should be(false)
    @identification.observation.num_identification_disagreements.should == 1
  end
  
  it "should NOT increment the observations num_identification_disagreements if the obs has no taxon" do
    # @identification.observation = Observation.find(:first, 
    #                                       :conditions => {:taxon_id => nil})
    @identification.observation = @unknown_obs
    @identification.user = users(:quentin)
    @identification.taxon = Taxon.find_by_name('Calypte anna')
    @identification.observation.num_identification_disagreements.should == 0
    @identification.save
    @identification.reload
    @identification.is_agreement?.should be(false)
    @identification.observation.num_identification_disagreements.should == 0
  end
  
  it "should consider an identification with a taxon that is a child of " + 
     "the observation's taxon to be in agreement" do
    taxon = Taxon.make
    parent = Taxon.make
    taxon.update_attributes(:parent => parent)
    observation = Observation.make(:taxon => parent)
    identification = Identification.make(:observation => observation, :taxon => taxon)
    identification.user.should_not be(identification.observation.user)
    identification.is_agreement?.should be_true
  end
  
  it "should not consider an identification with a taxon that is a parent " +
     "of the observation's taxon to be in agreement" do
    taxon = Taxon.make
    parent = Taxon.make
    taxon.update_attributes(:parent => parent)
    observation = Observation.make(:taxon => taxon)
    identification = Identification.make(:observation => observation, :taxon => parent)
    identification.user.should_not be(identification.observation.user)
    identification.is_agreement?.should be_false
  end
  
  it "should not consider itdentifications of different taxa in the " + 
     "different lineages to be in agreement" do
    @identification.user.should_not be(@identification.observation.user)
    @identification.taxon = Taxon.find_by_name('Aves')
    @identification.save
    @identification.reload
    @identification.is_agreement?.should be_false
  end
  
  it "should incremement the counter cache in users for an ident on someone else's observation" do
    @identification.user.should_not be(@identification.observation.user)
    old_count = @identification.user.identifications_count
    @identification.save
    @identification.user.identifications_count.should == old_count + 1
  end
  
  it "should NOT incremement the counter cache in users for an ident on one's OWN observation" do
    identification = Identification.new(
      :user => @unknown_obs.user, 
      :observation => @unknown_obs, 
      :taxon => Taxon.find_by_name('Calypte anna')
    )
    old_count = identification.user.identifications_count
    identification.save
    identification.user.identifications_count.should == old_count
  end
end

describe Identification, "deletion" do
  fixtures :observations, :identifications, :users, :taxa
  
  before(:each) do
    @observation = Observation.create(
      :species_guess => "Pacific Chorus Frog", 
      :taxon => taxa(:Pseudacris_regilla),
      :user => users(:adam))
    @unknown_obs = Observation.create(
      :species_guess => "You got me!",
      :user => users(:adam))
    @identification = Identification.create(
      :user => users(:ted),
      :observation => @observation,
      :taxon => taxa(:Pseudacris_regilla)
    )
  end
  
  it "should remove the taxon associated with the observation if it's the " +
     "observer's identification" do
    @observation.taxon.should_not be(nil)
    @observation.valid?.should be(true)
    @observation.reload
    @observation.identifications.should have_at_least(1).identification
    doomed_ident = @observation.identifications.select do |ident| 
      ident.user_id == @observation.user_id
    end.first
    doomed_ident.user_id.should be(@observation.user_id)
    doomed_ident.destroy
    @observation.reload
    @observation.taxon_id.should be(nil)
  end
  
  it "should decrement the observation's num_identification_agreements if " +
     "this was an agreement" do
    @observation.reload
    @observation.num_identification_agreements.should == 1
    @identification.destroy
    @observation.reload
    @observation.num_identification_agreements.should == 0
  end
  
  it "should decrement the observations num_identification_disagreements if this was a disagreement" do
    ident = Identification.create(
      :user => users(:quentin),
      :observation => @observation,
      :taxon => Taxon.find_by_name('Calypte anna')
    )
    puts "ident was invalid: #{ident.errors.full_messages.join(', ')}" unless ident.valid?
    @observation.reload
    @observation.num_identification_disagreements.should >= 1
    num_identification_disagreements = @observation.num_identification_disagreements
    ident.destroy
    @observation.reload
    @observation.num_identification_disagreements.should == num_identification_disagreements - 1
  end
  
  it "should decremement the counter cache in users for an ident on someone else's observation" do
    @identification.user.should_not be(@identification.observation.user)
    old_count = @identification.user.identifications_count
    user = @identification.user
    @identification.destroy
    user.reload
    user.identifications_count.should == old_count - 1
  end
  
  it "should NOT decremement the counter cache in users for an ident on one's OWN observation" do
    new_observation = Observation.create(
      :species_guess => "Pacific Chorus Frog", 
      :taxon => taxa(:Pseudacris_regilla),
      :user => users(:adam))
    puts "new_observations wasn't valid: #{new_observation.errors.full_messages.join(', ')}" unless new_observation.valid?
    new_observation.reload
    owners_ident = new_observation.identifications.select do |ident|
      ident.user_id == new_observation.user_id
    end.first
    user = new_observation.user
    old_count = user.identifications_count
    owners_ident.destroy
    user.reload
    user.identifications_count.should == old_count
  end
end
