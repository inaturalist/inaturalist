require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Identification, "creation" do
  
  it "should have a taxon" do 
    @id = Identification.make
    @id.taxon = nil
    @id.valid?
    @id.errors.on(:taxon_id).should_not be_blank
  end
  
  it "should have a user" do 
    @id = Identification.make
    @id.user = nil
    @id.valid?
    @id.errors.on(:user_id).should_not be_blank
  end
  
  it "should have an observation" do 
    @id = Identification.make
    @id.observation = nil
    @id.valid?
    @id.errors.on(:observation_id).should_not be_blank
  end
  
  it "should not let you identify the same observation twice" do
    @id = Identification.make
    bad_identification = Identification.new(
      :user => @id.user,
      :observation => @id.observation,
      :taxon => Taxon.make
    )
    bad_identification.valid?
    bad_identification.errors.on(:user_id).should_not be(nil)
  end
  
  it "should add a taxon to its observation if it's the observer's identification" do
    obs = Observation.make
    obs.taxon_id.should be_blank
    identification = Identification.make(:user => obs.user, :observation => obs, :taxon => Taxon.make)
    obs.reload
    obs.taxon_id.should == identification.taxon.id
  end
  
  it "should add a species_guess to a newly identified observation if the owner identified it and the species_guess was nil" do
    obs = Observation.make
    taxon = Taxon.make
    identification = Identification.make(
      :user => obs.user,
      :observation => obs,
      :taxon => taxon
    )
    obs.reload
    obs.species_guess.should == taxon.to_plain_s
  end
  
  it "should add an iconic_taxon_id to its observation if it's the observer's identification" do
    obs = Observation.make
    identification = Identification.make(
      :user => obs.user,
      :observation => obs
    )
    obs.reload
    obs.iconic_taxon_id.should == identification.taxon.iconic_taxon_id
  end
  
  it "should increment the observations num_identification_agreements if this is an agreement" do
    taxon = Taxon.make
    obs = Observation.make(:taxon => taxon)
    expect {
      Identification.make(:observation => obs, :taxon => taxon)
      obs.reload
    }.to change(obs, :num_identification_agreements).by(1)
  end
  
  it "should increment the observations num_identification_disagreements if this is an disagreement" do
    taxon = Taxon.make
    obs = Observation.make(:taxon => taxon)
    expect {
      Identification.make(:observation => obs)
      obs.reload
    }.to change(obs, :num_identification_disagreements).by(1)
  end
  
  it "should NOT increment the observations num_identification_disagreements if the obs has no taxon" do
    obs = Observation.make
    expect {
      Identification.make(:observation => obs)
      obs.reload
    }.to_not change(obs, :num_identification_agreements)
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
  
  it "should not consider itdentifications of different taxa in the different lineages to be in agreement" do
    taxon = Taxon.make
    child = Taxon.make(:parent => taxon)
    ident = Identification.make(:taxon => child)
    disagreement = Identification.make(:observation => ident.observation, :taxon => taxon)
    disagreement.is_agreement?.should be_false
  end
  
  it "should incremement the counter cache in users for an ident on someone else's observation" do
    user = User.make
    expect {
      Identification.make(:user => user)
    }.to change(user, :identifications_count).by(1)
  end
  
  it "should NOT incremement the counter cache in users for an ident on one's OWN observation" do
    user = User.make
    obs = Observation.make(:user => user)
    expect {
      Identification.make(:user => user, :observation => obs)
    }.to_not change(user, :identifications_count)
  end
  
  # Not sure how to do this with Delayed Job
  it "should update the user's life lists"
  
  it "should update observation quality_grade" do
    o = Observation.make(:taxon => Taxon.make, :latitude => 1, :longitude => 1, :observed_on_string => "yesterday")
    o.photos << LocalPhoto.make(:user => o.user)
    o.reload
    o.quality_grade.should == Observation::CASUAL_GRADE
    i = Identification.make(:observation => o, :taxon => o.taxon)
    o.reload
    o.quality_grade.should == Observation::RESEARCH_GRADE
  end
end

describe Identification, "deletion" do
  
  before(:each) do
    @observation = Observation.make(:taxon => Taxon.make)
    @unknown_obs = Observation.make(:user => @observation.user)
    @identification = Identification.make(:observation => @observation, :taxon => @observation.taxon)
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
    ident = Identification.make(:observation => @observation)
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
    new_observation = Observation.make(:taxon => Taxon.make)
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
    o.identifications.by(o.user).first.destroy
    Delayed::Job.delete_all
    
    Identification.make(:user => o.user, :observation => o, :taxon => Taxon.make)
    jobs = Delayed::Job.all(:conditions => ["created_at >= ?", stamp])
    
    pattern = /LOAD;ProjectList\nmethod\: \:refresh_with_observation\n/
    job = jobs.detect{|j| j.handler =~ pattern}
    job.should_not be_blank
    # puts job.handler.inspect
  end
  
  it "should queue a job to update check lists if changed from research grade" do
    o = make_research_grade_observation
    Delayed::Job.delete_all
    stamp = Time.now
    o.identifications.by(o.user).first.destroy
    jobs = Delayed::Job.all(:conditions => ["created_at >= ?", stamp])
    
    pattern = /LOAD;CheckList\nmethod\: \:refresh_with_observation\n/
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
    Identification.make(:taxon => o.taxon, :observation => o)
    o.reload
    o.quality_grade.should == Observation::RESEARCH_GRADE
    jobs = Delayed::Job.all(:conditions => ["created_at >= ?", stamp])
    pattern = /LOAD;CheckList\nmethod\: \:refresh_with_observation\n/
    job = jobs.detect{|j| j.handler =~ pattern}
    job.should_not be_blank
    # puts job.handler.inspect
  end
  
  it "should nilify curator_identification_id on project observations" do
    o = Observation.make
    p = Project.make
    pu = ProjectUser.make(:user => o.user, :project => p)
    po = ProjectObservation.make(:observation => o, :project => p)
    i = Identification.make(:user => p.user, :observation => o)
    Identification.run_update_curator_identification(i)
    po.reload
    po.curator_identification.should_not be_blank
    po.curator_identification_id.should == i.id
    i.destroy
    po.reload
    po.curator_identification_id.should be_blank
  end
end
