# require File.dirname(__FILE__) + '/../spec_helper.rb'
require File.expand_path("../../spec_helper", __FILE__)

describe Identification, "creation" do
  
  it "should have a taxon" do 
    @id = Identification.make!
    @id.taxon = nil
    @id.valid?
    @id.errors[:taxon].should_not be_blank
  end
  
  it "should have a user" do 
    @id = Identification.make!
    @id.user = nil
    @id.valid?
    @id.errors[:user].should_not be_blank
  end
  
  it "should have an observation" do 
    @id = Identification.make!
    @id.observation = nil
    @id.valid?
    @id.errors[:observation].should_not be_blank
  end

  it "should make older identifications not current" do
    old_ident = Identification.make!
    new_ident = Identification.make!(:observation => old_ident.observation, :user => old_ident.user)
    new_ident.should be_valid
    new_ident.should be_current
    old_ident.reload
    old_ident.should_not be_current
  end

  it "should not allow 2 current observations per user" do
    ident1 = Identification.make!
    idend2 = Identification.make!(:user => ident1.user, :observation => ident1.observation)
    ident1.reload
    ident1.should_not be_current
    ident1.update_attributes(:current => true)
    ident1.should_not be_valid
    ident1.errors[:current].should_not be_blank
  end
  
  it "should add a taxon to its observation if it's the observer's identification" do
    obs = Observation.make!
    obs.taxon_id.should be_blank
    identification = Identification.make!(:user => obs.user, :observation => obs, :taxon => Taxon.make!)
    obs.reload
    obs.taxon_id.should == identification.taxon.id
  end
  
  it "should add a species_guess to a newly identified observation if the owner identified it and the species_guess was nil" do
    obs = Observation.make!
    taxon = Taxon.make!
    identification = Identification.make!(
      :user => obs.user,
      :observation => obs,
      :taxon => taxon
    )
    obs.reload
    obs.species_guess.should == taxon.name
  end
  
  it "should add an iconic_taxon_id to its observation if it's the observer's identification" do
    obs = Observation.make!
    identification = Identification.make!(
      :user => obs.user,
      :observation => obs
    )
    obs.reload
    obs.iconic_taxon_id.should == identification.taxon.iconic_taxon_id
  end
  
  it "should increment the observations num_identification_agreements if this is an agreement" do
    taxon = Taxon.make!
    obs = Observation.make!(:taxon => taxon)
    old_count = obs.num_identification_agreements
    Identification.make!(:observation => obs, :taxon => taxon)
    obs.reload
    obs.num_identification_agreements.should eq old_count+1
  end

  it "should increment the observation's num_identification_agreements if this is an agreement and there are outdated idents" do
    taxon = Taxon.make!
    obs = Observation.make!(:taxon => taxon)
    old_ident = Identification.make!(:observation => obs, :taxon => taxon)
    obs.reload
    obs.num_identification_agreements.should eq(1)
    obs.reload
    Identification.make!(:observation => obs, :user => old_ident.user)
    obs.reload
    obs.num_identification_agreements.should eq(0)
  end
  
  it "should increment the observations num_identification_disagreements if this is a disagreement" do
    obs = Observation.make!(:taxon => Taxon.make!)
    old_count = obs.num_identification_disagreements
    Identification.make!(:observation => obs)
    obs.reload
    obs.num_identification_disagreements.should eq old_count+1
  end
  
  it "should NOT increment the observations num_identification_disagreements if the obs has no taxon" do
    obs = Observation.make!
    old_count = obs.num_identification_disagreements
    Identification.make!(:observation => obs)
    obs.reload
    obs.num_identification_disagreements.should eq old_count
  end
  
  it "should consider an identification with a taxon that is a child of " + 
     "the observation's taxon to be in agreement" do
    taxon = Taxon.make!
    parent = Taxon.make!
    taxon.update_attributes(:parent => parent)
    observation = Observation.make!(:taxon => parent, :prefers_community_taxon => false)
    identification = Identification.make!(:observation => observation, :taxon => taxon)
    identification.user.should_not be(identification.observation.user)
    identification.is_agreement?.should be true
  end
  
  it "should not consider an identification with a taxon that is a parent " +
     "of the observation's taxon to be in agreement" do
    taxon = Taxon.make!
    parent = Taxon.make!
    taxon.update_attributes(:parent => parent)
    observation = Observation.make!(:taxon => taxon, :prefers_community_taxon => false)
    identification = Identification.make!(:observation => observation, :taxon => parent)
    identification.user.should_not be(identification.observation.user)
    identification.is_agreement?.should be false
  end
  
  it "should not consider identifications of different taxa in the different lineages to be in agreement" do
    taxon = Taxon.make!
    child = Taxon.make!(:parent => taxon)
    o = Observation.make!(:prefers_community_taxon => false)
    ident = Identification.make!(:taxon => child, :observation => o)
    disagreement = Identification.make!(:observation => o, :taxon => taxon)
    disagreement.is_agreement?.should be false
  end
  
  it "should incremement the counter cache in users for an ident on someone else's observation" do
    user = User.make!
    expect {
      Identification.make!(:user => user)
    }.to change(user, :identifications_count).by(1)
  end
  
  it "should NOT incremement the counter cache in users for an ident on one's OWN observation" do
    user = User.make!
    obs = Observation.make!(:user => user)
    expect {
      Identification.make!(:user => user, :observation => obs)
    }.to_not change(user, :identifications_count)
  end
  
  # Not sure how to do this with Delayed Job
  it "should update the user's life lists"
  
  it "should update observation quality_grade" do
    o = Observation.make!(:taxon => Taxon.make!, :latitude => 1, :longitude => 1, :observed_on_string => "yesterday")
    o.photos << LocalPhoto.make!(:user => o.user)
    o.reload
    o.quality_grade.should == Observation::CASUAL_GRADE
    i = Identification.make!(:observation => o, :taxon => o.taxon)
    o.reload
    o.quality_grade.should == Observation::RESEARCH_GRADE
  end

  it "should update observation quality grade after disagreement" do
    o = make_research_grade_observation(:prefers_community_taxon => false)
    o.should be_research_grade
    i = Identification.make!(:observation => o)
    Identification.make!(:observation => o, :taxon => i.taxon)
    o.reload
    o.should_not be_research_grade
    o.owners_identification.destroy
    o.reload
    o.owners_identification.should be_blank
    Identification.make!(:user => o.user, :observation => o, :taxon => i.taxon)
    o.reload
    o.should be_research_grade
  end

  it "should obscure the observation's coordinates if the taxon is threatened" do
    o = Observation.make!(:latitude => 1, :longitude => 1)
    o.should_not be_coordinates_obscured
    i = Identification.make!(:taxon => Taxon.make!(:threatened), :observation => o, :user => o.user)
    o.reload
    o.should be_coordinates_obscured
  end

  it "should set the observation's community taxon" do
    t = Taxon.make!
    o = Observation.make!(:taxon => t)
    o.community_taxon.should be_blank
    i = Identification.make!(:observation => o, :taxon => t)
    o.reload
    o.community_taxon.should eq(t)
  end

  it "should touch the observation" do
    o = Observation.make!
    updated_at_was = o.updated_at
    op = Identification.make!(:observation => o, :user => o.user)
    o.reload
    updated_at_was.should < o.updated_at
  end
end

describe Identification, "updating" do
  it "should not change current status of other identifications" do
    i1 = Identification.make!
    i2 = Identification.make!(:observation => i1.observation, :user => i1.user)
    i1.reload
    i2.reload
    i1.should_not be_current
    i2.should be_current
    i1.update_attributes(:body => "foo")
    i1.reload
    i2.reload
    i1.should_not be_current
    i2.should be_current
  end
end

describe Identification, "deletion" do
  before(:all) do
    # some identification deletion callbacks need to happen after the transaction is complete
    DatabaseCleaner.strategy = :truncation
  end

  after(:all) do
    DatabaseCleaner.strategy = :transaction
  end
  
  before(:each) do
    @observation = Observation.make!(:taxon => Taxon.make!)
    @unknown_obs = Observation.make!(:user => @observation.user)
    @identification = Identification.make!(:observation => @observation, :taxon => @observation.taxon)
  end
  
  it "should remove the taxon associated with the observation if it's the " +
     "observer's identification" do
    @observation.taxon.should_not be(nil)
    @observation.valid?.should be(true)
    @observation.reload
    expect(@observation.identifications.length).to be >= 1
    doomed_ident = @observation.identifications.select do |ident| 
      ident.user_id == @observation.user_id
    end.first
    doomed_ident.user_id.should be(@observation.user_id)
    doomed_ident.destroy
    @observation.reload
    @observation.taxon_id.should be(nil)
  end
  
  it "should decrement the observation's num_identification_agreements if this was an agreement" do
    @observation.reload
    @observation.num_identification_agreements.should == 1
    @identification.destroy
    @observation.reload
    @observation.num_identification_agreements.should == 0
  end
  
  it "should decrement the observations num_identification_disagreements if this was a disagreement" do
    ident = Identification.make!(:observation => @observation)
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
    new_observation = Observation.make!(:taxon => Taxon.make!)
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
  
  it "should update observation quality_grade" do
    o = make_research_grade_observation
    o.quality_grade.should == Observation::RESEARCH_GRADE
    o.identifications.last.destroy
    o.reload
    o.quality_grade.should == Observation::CASUAL_GRADE
  end
  
  it "should update observation quality_grade if made by another user" do
    o = make_research_grade_observation
    o.quality_grade.should == Observation::RESEARCH_GRADE
    o.identifications.each {|ident| ident.destroy if ident.user_id != o.user_id}
    o.reload
    o.quality_grade.should == Observation::CASUAL_GRADE
  end
  
  it "should queue a job to update project lists if owners ident" do
    o = make_research_grade_observation
    Delayed::Job.delete_all
    stamp = Time.now
    o.owners_identification.destroy
    Delayed::Job.delete_all
    
    Identification.make!(:user => o.user, :observation => o, :taxon => Taxon.make!)
    jobs = Delayed::Job.where("created_at >= ?", stamp)

    pattern = /ProjectList.*refresh_with_observation/m
    job = jobs.detect{|j| j.handler =~ pattern}
    job.should_not be_blank
    # puts job.handler.inspect
  end
  
  it "should queue a job to update check lists if changed from research grade" do
    o = make_research_grade_observation
    Delayed::Job.delete_all
    stamp = Time.now
    o.identifications.by(o.user).first.destroy
    jobs = Delayed::Job.where("created_at >= ?", stamp)
    
    pattern = /CheckList.*refresh_with_observation/m
    job = jobs.detect{|j| j.handler =~ pattern}
    job.should_not be_blank
    # puts job.handler.inspect
  end
  
  it "should queue a job to update check lists if research grade" do
    o = make_research_grade_observation
    o.identifications.each {|ident| ident.destroy if ident.user_id != o.user_id}
    o.reload
    o.quality_grade.should == Observation::CASUAL_GRADE
    stamp = Time.now
    Delayed::Job.delete_all
    Identification.make!(:taxon => o.taxon, :observation => o)
    o.reload
    o.quality_grade.should == Observation::RESEARCH_GRADE
    jobs = Delayed::Job.where("created_at >= ?", stamp)
    pattern = /CheckList.*refresh_with_observation/m
    job = jobs.detect{|j| j.handler =~ pattern}
    job.should_not be_blank
    # puts job.handler.inspect
  end
  
  it "should nilify curator_identification_id on project observations if no other current identification" do
    o = Observation.make!
    p = Project.make!
    pu = ProjectUser.make!(:user => o.user, :project => p)
    po = ProjectObservation.make!(:observation => o, :project => p)
    i = Identification.make!(:user => p.user, :observation => o)
    Identification.run_update_curator_identification(i)
    po.reload
    po.curator_identification.should_not be_blank
    po.curator_identification_id.should == i.id
    i.destroy
    po.reload
    po.curator_identification_id.should be_blank
  end

  it "should set curator_identification_id on project observations to last current identification" do
    o = Observation.make!
    p = Project.make!
    pu = ProjectUser.make!(:user => o.user, :project => p)
    po = ProjectObservation.make!(:observation => o, :project => p)
    i1 = Identification.make!(:user => p.user, :observation => o)
    Identification.run_update_curator_identification(i1)
    i2 = Identification.make!(:user => p.user, :observation => o)
    Identification.run_update_curator_identification(i2)
    po.reload
    po.curator_identification_id.should == i2.id
    i2.destroy
    Identification.run_revisit_curator_identification(o.id, i2.user_id)
    po.reload
    po.curator_identification_id.should == i1.id
  end

  it "should set the user's last identification as current" do
    ident1 = Identification.make!
    ident2 = Identification.make!(:observation => ident1.observation, :user => ident1.user)
    ident3 = Identification.make!(:observation => ident1.observation, :user => ident1.user)
    ident2.reload
    ident2.should_not be_current
    ident3.destroy
    ident2.reload
    ident2.should be_current
    ident1.reload
    ident1.should_not be_current
  end

  it "should set observation taxon to that of last current ident for owner" do
    o = Observation.make!(:taxon => Taxon.make!)
    ident1 = o.owners_identification
    ident2 = Identification.make!(:observation => o, :user => o.user)
    ident3 = Identification.make!(:observation => o, :user => o.user)
    o.reload
    o.taxon_id.should eq(ident3.taxon_id)
    ident3.destroy
    o.reload
    o.taxon_id.should eq(ident2.taxon_id)
  end

  it "should set the observation's community taxon if remaining identifications" do
    load_test_taxa
    o = Observation.make!(:taxon => @Calypte_anna)
    o.community_taxon.should be_blank
    i1 = Identification.make!(:observation => o, :taxon => @Calypte_anna)
    i3 = Identification.make!(:observation => o, :taxon => @Calypte_anna)
    i2 = Identification.make!(:observation => o, :taxon => @Pseudacris_regilla)
    o.reload
    o.community_taxon.should eq(@Calypte_anna)
    i1.destroy
    o.reload
    o.community_taxon.should eq(@Chordata) # consensus
  end

  it "should remove the observation's community taxon if no more identifications" do
    o = Observation.make!(:taxon => Taxon.make!)
    i = Identification.make!(:observation => o, :taxon => o.taxon)
    o.reload
    o.community_taxon.should eq o.taxon
    i.destroy
    o.reload
    o.community_taxon.should be_blank
  end
end

describe Identification, "captive" do
  it "should vote yes on the wild quality metric if 1" do
    i = Identification.make!(:captive_flag => "1")
    o = i.observation
    o.quality_metrics.should_not be_blank
    o.quality_metrics.first.user.should eq(i.user)
    o.quality_metrics.first.should_not be_agree
  end

  it "should vote no on the wild quality metric if 0 and metric exists" do
    i = Identification.make!(:captive_flag => "1")
    o = i.observation
    o.quality_metrics.should_not be_blank
    i.update_attributes(:captive_flag => "0")
    o.reload
    o.quality_metrics.first.should be_agree
  end

  it "should not alter quality metrics if nil" do
    i = Identification.make!(:captive_flag => nil)
    o = i.observation
    o.quality_metrics.should be_blank
  end

  it "should not alter quality metrics if 0 and not metrics exist" do
    i = Identification.make!(:captive_flag => "0")
    o = i.observation
    o.quality_metrics.should be_blank
  end
end
