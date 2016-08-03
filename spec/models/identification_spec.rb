require "spec_helper"

describe Identification, "creation" do

  before(:all) { User.destroy_all }

  it "should have a taxon" do 
    @id = Identification.make!
    @id.taxon = nil
    @id.valid?
    expect(@id.errors[:taxon]).not_to be_blank
  end
  
  it "should have a user" do 
    @id = Identification.make!
    @id.user = nil
    @id.valid?
    expect(@id.errors[:user]).not_to be_blank
  end
  
  it "should have an observation" do 
    @id = Identification.make!
    @id.observation = nil
    @id.valid?
    expect(@id.errors[:observation]).not_to be_blank
  end

  it "should make older identifications not current" do
    old_ident = Identification.make!
    new_ident = Identification.make!(:observation => old_ident.observation, :user => old_ident.user)
    expect(new_ident).to be_valid
    expect(new_ident).to be_current
    old_ident.reload
    expect(old_ident).not_to be_current
  end

  # it "should not allow 2 current observations per user" do
  #   ident1 = Identification.make!
  #   idend2 = Identification.make!(:user => ident1.user, :observation => ident1.observation)
  #   ident1.reload
  #   expect(ident1).not_to be_current
  #   ident1.update_attributes(:current => true)
  #   expect(ident1).not_to be_valid
  #   expect(ident1.errors[:current]).not_to be_blank
  # end
  
  it "should add a taxon to its observation if it's the observer's identification" do
    obs = Observation.make!
    expect(obs.taxon_id).to be_blank
    identification = Identification.make!(:user => obs.user, :observation => obs, :taxon => Taxon.make!)
    obs.reload
    expect(obs.taxon_id).to eq identification.taxon.id
  end
  
  it "should add a taxon to its observation if it's someone elses identification" do
    obs = Observation.make!
    expect(obs.taxon_id).to be_blank
    expect(obs.community_taxon).to be_blank
    identification = Identification.make!(:observation => obs, :taxon => Taxon.make!)
    obs.reload
    expect(obs.taxon_id).to eq identification.taxon.id
    expect(obs.community_taxon).to be_blank
  end
  
  it "shouldn't add a taxon to its observation if it's someone elses identification but the observation user rejects community IDs" do
    u = User.make!(:prefers_community_taxa => false)
    obs = Observation.make!(:user => u)
    expect(obs.taxon_id).to be_blank
    expect(obs.community_taxon).to be_blank
    identification = Identification.make!(:observation => obs, :taxon => Taxon.make!)
    obs.reload
    expect(obs.taxon_id).to be_blank
    expect(obs.community_taxon).to be_blank
  end
  
  it "shouldn't create an ID by the obs owner if someone else adds an ID" do
    obs = Observation.make!
    expect(obs.taxon_id).to be_blank
    expect(obs.identifications.count).to eq 0
    identification = Identification.make!(:observation => obs, :taxon => Taxon.make!)
    obs.reload
    expect(obs.taxon_id).not_to be_blank
    expect(obs.identifications.count).to eq 1
  end
  
  it "should not modify species_guess to an observation if there's a taxon_id and the taxon_id didn't change" do
    obs = Observation.make!
    taxon = Taxon.make!
    taxon2 = Taxon.make!
    identification = Identification.make!(
      :user => obs.user,
      :observation => obs,
      :taxon => taxon
    )
    obs.reload
    user = User.make!
    identification = Identification.make!(
      :user => user,
      :observation => obs,
      :taxon => taxon2
    )
    obs.reload
    expect(obs.species_guess).to eq taxon.name
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
    expect(obs.species_guess).to eq taxon.name
  end
  
  it "should add an iconic_taxon_id to its observation if it's the observer's identification" do
    obs = Observation.make!
    identification = Identification.make!(
      :user => obs.user,
      :observation => obs
    )
    obs.reload
    expect(obs.iconic_taxon_id).to eq identification.taxon.iconic_taxon_id
  end
  
  it "should increment the observations num_identification_agreements if this is an agreement" do
    taxon = Taxon.make!
    obs = Observation.make!(:taxon => taxon)
    old_count = obs.num_identification_agreements
    Identification.make!(:observation => obs, :taxon => taxon)
    obs.reload
    expect(obs.num_identification_agreements).to eq old_count+1
  end

  it "should increment the observation's num_identification_agreements if this is an agreement and there are outdated idents" do
    taxon = Taxon.make!
    obs = Observation.make!(:taxon => taxon)
    old_ident = Identification.make!(:observation => obs, :taxon => taxon)
    obs.reload
    expect(obs.num_identification_agreements).to eq(1)
    obs.reload
    Identification.make!(:observation => obs, :user => old_ident.user)
    obs.reload
    expect(obs.num_identification_agreements).to eq(0)
  end
  
  it "should increment the observations num_identification_disagreements if this is a disagreement" do
    obs = Observation.make!(:taxon => Taxon.make!)
    old_count = obs.num_identification_disagreements
    Identification.make!(:observation => obs)
    obs.reload
    expect(obs.num_identification_disagreements).to eq old_count+1
  end
  
  it "should NOT increment the observations num_identification_disagreements if the obs has no taxon" do
    obs = Observation.make!
    old_count = obs.num_identification_disagreements
    Identification.make!(:observation => obs)
    obs.reload
    expect(obs.num_identification_disagreements).to eq old_count
  end
  
  it "should NOT increment the observations num_identification_agreements or num_identification_disagreements if theres just one ID" do
    taxon = Taxon.make!
    obs = Observation.make!
    old_agreement_count = obs.num_identification_agreements
    old_disagreement_count = obs.num_identification_disagreements
    expect(obs.community_taxon).to be_blank
    Identification.make!(:observation => obs, :taxon => taxon)
    obs.reload
    expect(obs.num_identification_agreements).to eq old_agreement_count
    expect(obs.num_identification_disagreements).to eq old_disagreement_count
    expect(obs.community_taxon).to be_blank
    expect(obs.identifications.count).to eq 1
  end
  
  it "should consider an identification with a taxon that is a child of " + 
     "the observation's taxon to be in agreement" do
    taxon = Taxon.make!
    parent = Taxon.make!
    taxon.update_attributes(:parent => parent)
    observation = Observation.make!(:taxon => parent, :prefers_community_taxon => false)
    identification = Identification.make!(:observation => observation, :taxon => taxon)
    expect(identification.user).not_to be(identification.observation.user)
    expect(identification.is_agreement?).to be true
  end
  
  it "should not consider an identification with a taxon that is a parent " +
     "of the observation's taxon to be in agreement" do
    taxon = Taxon.make!
    parent = Taxon.make!
    taxon.update_attributes(:parent => parent)
    observation = Observation.make!(:taxon => taxon, :prefers_community_taxon => false)
    identification = Identification.make!(:observation => observation, :taxon => parent)
    expect(identification.user).not_to be(identification.observation.user)
    expect(identification.is_agreement?).to be false
  end
  
  it "should not consider identifications of different taxa in the different lineages to be in agreement" do
    taxon = Taxon.make!
    child = Taxon.make!(:parent => taxon)
    o = Observation.make!(:prefers_community_taxon => false)
    ident = Identification.make!(:taxon => child, :observation => o)
    disagreement = Identification.make!(:observation => o, :taxon => taxon)
    expect(disagreement.is_agreement?).to be false
  end
  
  describe "user counter cache" do
    before(:all) { DatabaseCleaner.strategy = :truncation }
    after(:all)  { DatabaseCleaner.strategy = :transaction }

    it "should incremement for an ident on someone else's observation, with delay" do
      taxon = Taxon.make!
      obs = Observation.make!(taxon: taxon)
      user = User.make!
      Delayed::Job.destroy_all
      expect( Delayed::Job.count ).to eq 0
      expect( user.identifications_count ).to eq 0
      Identification.make!(user: user, observation: obs, taxon: taxon)
      expect( Delayed::Job.count ).to be > 1
      user.reload
      expect( user.identifications_count ).to eq 0
      Delayed::Worker.new.work_off
      user.reload
      expect( Delayed::Job.count ).to eq 0
      expect( user.identifications_count ).to eq 1
    end
    
    it "should NOT incremement for an ident on one's OWN observation" do
      user = User.make!
      obs = Observation.make!(user: user)
      expect {
        without_delay{ Identification.make!(user: user, observation: obs) }
      }.to_not change(user, :identifications_count)
    end
  end
  
  # Not sure how to do this with Delayed Job
  it "should update the user's life lists"
  
  it "should update observation quality_grade" do
    o = make_research_grade_candidate_observation(taxon: Taxon.make!(rank: Taxon::SPECIES))
    expect( o.quality_grade ).to eq Observation::NEEDS_ID
    i = Identification.make!(:observation => o, :taxon => o.taxon)
    o.reload
    expect( o.quality_grade ).to eq Observation::RESEARCH_GRADE
  end

  it "should update observation quality grade after disagreement" do
    o = make_research_grade_observation(:prefers_community_taxon => false)
    expect(o).to be_research_grade
    i = Identification.make!(observation: o, taxon: Taxon.make!(:species))
    Identification.make!(observation: o, taxon: i.taxon)
    o.reload
    expect(o).not_to be_research_grade
    o.owners_identification.destroy
    o.reload
    expect(o.owners_identification).to be_blank
    Identification.make!(user: o.user, observation: o, taxon: i.taxon)
    o.reload
    expect(o).to be_research_grade
  end

  it "should obscure the observation's coordinates if the taxon is threatened" do
    o = Observation.make!(:latitude => 1, :longitude => 1)
    expect(o).not_to be_coordinates_obscured
    i = Identification.make!(:taxon => make_threatened_taxon, :observation => o, :user => o.user)
    o.reload
    expect(o).to be_coordinates_obscured
  end

  it "should set the observation's community taxon" do
    t = Taxon.make!
    o = Observation.make!(:taxon => t)
    expect(o.community_taxon).to be_blank
    i = Identification.make!(:observation => o, :taxon => t)
    o.reload
    expect(o.community_taxon).to eq(t)
  end

  it "should touch the observation" do
    o = Observation.make!
    updated_at_was = o.updated_at
    op = Identification.make!(:observation => o, :user => o.user)
    o.reload
    expect(updated_at_was).to be < o.updated_at
  end

  it "creates observation reviews if they dont exist" do
    o = Observation.make!
    expect(o.observation_reviews.count).to eq 0
    Identification.make!(observation: o, user: o.user)
    o.reload
    expect(o.observation_reviews.count).to eq 1
  end

  it "updates existing reviews" do
    o = Observation.make!
    r = ObservationReview.make!(observation: o, user: o.user, updated_at: 1.day.ago)
    Identification.make!(observation: o, user: o.user)
    o.reload
    expect(o.observation_reviews.first).to eq r
    expect(o.observation_reviews.first.updated_at).to be > r.updated_at
  end

  it "should set curator_identification_id on project observations to last current identification" do
    o = Observation.make!
    p = Project.make!
    pu = ProjectUser.make!(:user => o.user, :project => p)
    po = ProjectObservation.make!(:observation => o, :project => p)
    i1 = Identification.make!(:user => p.user, :observation => o)
    Delayed::Worker.new.work_off
    po.reload
    expect(po.curator_identification_id).to eq i1.id
  end
end

describe Identification, "updating" do
  it "should not change current status of other identifications" do
    i1 = Identification.make!
    i2 = Identification.make!(:observation => i1.observation, :user => i1.user)
    i1.reload
    i2.reload
    expect(i1).not_to be_current
    expect(i2).to be_current
    i1.update_attributes(:body => "foo")
    i1.reload
    i2.reload
    expect(i1).not_to be_current
    expect(i2).to be_current
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
    @observation = Observation.make!(:taxon => Taxon.make!, :prefers_community_taxon => false)
    @unknown_obs = Observation.make!(:user => @observation.user)
    @identification = Identification.make!(:observation => @observation, :taxon => @observation.taxon)
  end
  
  it "should remove the taxon associated with the observation if it's the " +
     "observer's identification and obs does not prefers_community_taxon" do
    expect(@observation.taxon).not_to be(nil)
    expect(@observation.valid?).to be(true)
    @observation.reload
    expect(@observation.identifications.length).to be >= 1
    doomed_ident = @observation.identifications.select do |ident| 
      ident.user_id == @observation.user_id
    end.first
    expect(doomed_ident.user_id).to be(@observation.user_id)
    doomed_ident.destroy
    @observation.reload
    expect(@observation.taxon_id).to be(nil)
  end
  
  it "should NOT remove the taxon associated with the observation if it's the " +
     "observer's identification and obs prefers_community_taxon " do
    @observation_prefers_community_taxon = Observation.make!(:taxon => Taxon.make!)
    @identification_prefers_community_taxon = Identification.make!(:observation => @observation_prefers_community_taxon, :taxon => @observation_prefers_community_taxon.taxon)
    expect(@observation_prefers_community_taxon.taxon).not_to be(nil)
    expect(@observation_prefers_community_taxon.valid?).to be(true)
    @observation_prefers_community_taxon.reload
    expect(@observation_prefers_community_taxon.identifications.length).to be >= 1
    doomed_ident = @observation_prefers_community_taxon.identifications.select do |ident| 
      ident.user_id == @observation_prefers_community_taxon.user_id
    end.first
    expect(doomed_ident.user_id).to be(@observation_prefers_community_taxon.user_id)
    doomed_ident.destroy
    @observation_prefers_community_taxon.reload
    expect(@observation_prefers_community_taxon.taxon_id).not_to be(nil)
  end
  
  it "should decrement the observation's num_identification_agreements if this was an agreement" do
    @observation.reload
    expect(@observation.num_identification_agreements).to eq 1
    @identification.destroy
    @observation.reload
    expect(@observation.num_identification_agreements).to eq 0
  end
  
  it "should decrement the observations num_identification_disagreements if this was a disagreement" do
    ident = Identification.make!(:observation => @observation)
    @observation.reload
    expect(@observation.num_identification_disagreements).to be >= 1
    num_identification_disagreements = @observation.num_identification_disagreements
    ident.destroy
    @observation.reload
    expect(@observation.num_identification_disagreements).to eq num_identification_disagreements - 1
  end
  
  it "should decremement the counter cache in users for an ident on someone else's observation" do
    expect(@identification.user).not_to be(@identification.observation.user)
    old_count = @identification.user.identifications_count
    user = @identification.user
    @identification.destroy
    user.reload
    expect(user.identifications_count).to eq [old_count, 0].min
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
    expect(user.identifications_count).to eq old_count
  end
  
  it "should update observation quality_grade" do
    o = make_research_grade_observation
    expect(o.quality_grade).to eq Observation::RESEARCH_GRADE
    o.identifications.last.destroy
    o.reload
    expect(o.quality_grade).to eq Observation::NEEDS_ID
  end
  
  it "should update observation quality_grade if made by another user" do
    o = make_research_grade_observation
    expect(o.quality_grade).to eq Observation::RESEARCH_GRADE
    o.identifications.each {|ident| ident.destroy if ident.user_id != o.user_id}
    o.reload
    expect(o.quality_grade).to eq Observation::NEEDS_ID
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
    expect(job).not_to be_blank
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
    expect(job).not_to be_blank
    # puts job.handler.inspect
  end
  
  it "should queue a job to update check lists if research grade" do
    o = make_research_grade_observation
    o.identifications.each {|ident| ident.destroy if ident.user_id != o.user_id}
    o.reload
    expect(o.quality_grade).to eq Observation::NEEDS_ID
    stamp = Time.now
    Delayed::Job.delete_all
    Identification.make!(:taxon => o.taxon, :observation => o)
    o.reload
    expect(o.quality_grade).to eq Observation::RESEARCH_GRADE
    jobs = Delayed::Job.where("created_at >= ?", stamp)
    pattern = /CheckList.*refresh_with_observation/m
    job = jobs.detect{|j| j.handler =~ pattern}
    expect(job).not_to be_blank
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
    expect(po.curator_identification).not_to be_blank
    expect(po.curator_identification_id).to eq i.id
    i.destroy
    po.reload
    expect(po.curator_identification_id).to be_blank
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
    expect(po.curator_identification_id).to eq i2.id
    i2.destroy
    Identification.run_revisit_curator_identification(o.id, i2.user_id)
    po.reload
    expect(po.curator_identification_id).to eq i1.id
  end

  it "should set the user's last identification as current" do
    ident1 = Identification.make!
    ident2 = Identification.make!(:observation => ident1.observation, :user => ident1.user)
    ident3 = Identification.make!(:observation => ident1.observation, :user => ident1.user)
    ident2.reload
    expect(ident2).not_to be_current
    ident3.destroy
    ident2.reload
    expect(ident2).to be_current
    ident1.reload
    expect(ident1).not_to be_current
  end

  it "should set observation taxon to that of last current ident for owner" do
    o = Observation.make!(:taxon => Taxon.make!)
    ident1 = o.owners_identification
    ident2 = Identification.make!(:observation => o, :user => o.user)
    ident3 = Identification.make!(:observation => o, :user => o.user)
    o.reload
    expect(o.taxon_id).to eq(ident3.taxon_id)
    ident3.destroy
    o.reload
    expect(o.taxon_id).to eq(ident2.taxon_id)
  end

  it "should set the observation's community taxon if remaining identifications" do
    load_test_taxa
    o = Observation.make!(:taxon => @Calypte_anna)
    expect(o.community_taxon).to be_blank
    i1 = Identification.make!(:observation => o, :taxon => @Calypte_anna)
    i3 = Identification.make!(:observation => o, :taxon => @Calypte_anna)
    i2 = Identification.make!(:observation => o, :taxon => @Pseudacris_regilla)
    o.reload
    expect(o.community_taxon).to eq(@Calypte_anna)
    i1.destroy
    o.reload
    expect(o.community_taxon).to eq(@Chordata) # consensus
  end

  it "should remove the observation's community taxon if no more identifications" do
    o = Observation.make!(:taxon => Taxon.make!)
    i = Identification.make!(:observation => o, :taxon => o.taxon)
    o.reload
    expect(o.community_taxon).to eq o.taxon
    i.destroy
    o.reload
    expect(o.community_taxon).to be_blank
  end

  it "destroys automatically created reviews" do
    o = Observation.make!
    i = Identification.make!(observation: o, user: o.user)
    expect(o.observation_reviews.count).to eq 1
    i.destroy
    o.reload
    expect(o.observation_reviews.count).to eq 0
  end

  it "does not destroy user created reviews" do
    o = Observation.make!
    i = Identification.make!(observation: o, user: o.user)
    o.observation_reviews.destroy_all
    r = ObservationReview.make!(observation: o, user: o.user, user_added: true)
    expect(o.observation_reviews.count).to eq 1
    i.destroy
    o.reload
    expect(o.observation_reviews.count).to eq 1
  end
end

describe Identification, "captive" do
  it "should vote yes on the wild quality metric if 1" do
    i = Identification.make!(:captive_flag => "1")
    o = i.observation
    expect(o.quality_metrics).not_to be_blank
    expect(o.quality_metrics.first.user).to eq(i.user)
    expect(o.quality_metrics.first).not_to be_agree
  end

  it "should vote no on the wild quality metric if 0 and metric exists" do
    i = Identification.make!(:captive_flag => "1")
    o = i.observation
    expect(o.quality_metrics).not_to be_blank
    i.update_attributes(:captive_flag => "0")
    o.reload
    expect(o.quality_metrics.first).not_to be_agree
  end

  it "should not alter quality metrics if nil" do
    i = Identification.make!(:captive_flag => nil)
    o = i.observation
    expect(o.quality_metrics).to be_blank
  end

  it "should not alter quality metrics if 0 and not metrics exist" do
    i = Identification.make!(:captive_flag => "0")
    o = i.observation
    expect(o.quality_metrics).to be_blank
  end
end

describe Identification do
  describe "mentions" do
    it "knows what users have been mentioned" do
      u = User.make!
      i = Identification.make!(body: "hey @#{ u.login }")
      expect( i.mentioned_users ).to eq [ u ]
    end

    it "generates mention updates" do
      u = User.make!
      i = without_delay { Identification.make!(body: "hey @#{ u.login }") }
      expect( UpdateAction.where(notifier: i, notification: "mention").count ).to eq 1
      expect( UpdateAction.where(notifier: i, notification: "mention").first.
        update_subscribers.first.subscriber).to eq u
    end
  end

  describe "run_update_curator_identification" do
    it "indexes the observation in elasticsearch" do
      o = Observation.make!
      p = Project.make!
      pu = ProjectUser.make!(user: o.user, project: p)
      po = ProjectObservation.make!(observation: o, project: p)
      i = Identification.make!(user: p.user, observation: o)
      expect( Observation.page_of_results(project_id: p.id, pcid: true).
        total_entries ).to eq 0
      Identification.run_update_curator_identification(i)
      expect( Observation.page_of_results(project_id: p.id, pcid: true).
        total_entries ).to eq 1
    end
  end
end

describe Identification, "category" do
  before(:all) { DatabaseCleaner.strategy = :truncation }
  after(:all)  { DatabaseCleaner.strategy = :transaction }
  let( :o ) { Observation.make! }
  let(:parent) { Taxon.make!( rank: Taxon::GENUS ) }
  let(:child) { Taxon.make!( rank: Taxon::SPECIES, parent: parent ) }
  describe "should be improving when" do
    it "is the first that matches the community ID among several IDs" do
      i1 = Identification.make!( observation: o )
      i2 = Identification.make!( observation: o, taxon: i1.taxon )
      o.reload
      i1.reload
      expect( o.community_taxon ).to eq i1.taxon
      expect( i1.observation.identifications.count ).to eq 2
      expect( i1.category ).to eq Identification::IMPROVING
    end
    it "qualifies but isn't current" do
      i1 = Identification.make!( observation: o, taxon: parent )
      i2 = Identification.make!( observation: o, taxon: child )
      i1.reload
      expect( i1.category ).to eq Identification::IMPROVING
      i3 = Identification.make!( observation: o, taxon: child, user: i1.user )
      i1.reload
      expect( i1.category ).to eq Identification::IMPROVING
    end
    it "is an ancestor of the community taxon and was not added after the first ID of the community taxon" do
      i1 = Identification.make!( observation: o, taxon: parent )
      i2 = Identification.make!( observation: o, taxon: child )
      i3 = Identification.make!( observation: o, taxon: child )
      i4 = Identification.make!( observation: o, taxon: child )
      o.reload
      expect( o.community_taxon ).to eq child
      i1.reload
      expect( i1.category ).to eq Identification::IMPROVING
    end
  end
  describe "should be maverick when" do
    it "the community taxon is not an ancestor" do
      i1 = Identification.make!( observation: o )
      i2 = Identification.make!( observation: o, taxon: i1.taxon )
      i3 = Identification.make!( observation: o )
      i3.reload
      expect( i3.category ).to eq Identification::MAVERICK
    end
    # it "is a higher-rank disagreement with the community taxon" do
    #   i1 = Identification.make!( observation: o, taxon: child )
    #   i2 = Identification.make!( observation: o, taxon: child )
    #   i3 = Identification.make!( observation: o, taxon: child )
    #   i4 = Identification.make!( observation: o, taxon: parent )
    #   i4.reload
    #   expect( i4.category ).to eq Identification::MAVERICK
    # end
  end
  describe "should be leading when" do
    it "is the only ID" do
      i = Identification.make!
      expect( i.category ).to eq Identification::LEADING
    end
    it "has a taxon that is a descendant of the community taxon" do
      i1 = Identification.make!( observation: o, taxon: parent )
      i2 = Identification.make!( observation: o, taxon: parent )
      i3 = Identification.make!( observation: o, taxon: child )
      expect( i3.category ).to eq Identification::LEADING
    end
  end
  describe "should be supporting when" do
    it "matches the community taxon but is not the first to do so" do
      i1 = Identification.make!( observation: o )
      i2 = Identification.make!( observation: o, taxon: i1.taxon )
      expect( i2.category ).to eq Identification::SUPPORTING
    end
    it "descends from the community taxon but is not the first identification of that taxon" do
      i1 = Identification.make!( observation: o, taxon: parent )
      i2 = Identification.make!( observation: o, taxon: child )
      i3 = Identification.make!( observation: o, taxon: child )
      expect( i3.category ).to eq Identification::SUPPORTING
    end
  end
  describe "examples: " do
    let(:o) { Observation.make! }
    describe "sequence of IDs along the same ancestry" do
      before do
        load_test_taxa
        @sequence = [
          Identification.make!( observation: o, taxon: @Chordata ),
          Identification.make!( observation: o, taxon: @Aves ),
          Identification.make!( observation: o, taxon: @Calypte ),
          Identification.make!( observation: o, taxon: @Calypte_anna )
        ]
        @sequence.each(&:reload)
        @sequence
      end
      it "should all be improving until the community taxon" do
        o.reload
        expect( o.community_taxon ).to eq @Calypte
        expect( @sequence[0].category ).to eq Identification::IMPROVING
        expect( @sequence[1].category ).to eq Identification::IMPROVING
      end
      it "should end with a leading ID" do
        expect( @sequence.last.category ).to eq Identification::LEADING
      end
      it "should continue to have improving IDs even if the first identifier agrees with the last" do
        first = @sequence[0]
        i = Identification.make!( observation: o, taxon: @sequence[-1].taxon, user: first.user )
        first.reload
        @sequence[1].reload
        expect( first ).not_to be_current
        expect( first.category ).to eq Identification::IMPROVING
        expect( @sequence[1].category ).to eq Identification::IMPROVING
      end
    end
  end
  describe "conservative disagreement" do
    before do
      load_test_taxa
      @sequence = [
        Identification.make!( observation: o, taxon: @Calypte_anna ),
        Identification.make!( observation: o, taxon: @Calypte ),
        Identification.make!( observation: o, taxon: @Calypte )
      ]
      @sequence.each(&:reload)
    end
    it "should consider disagreements that match the community taxon to be improving" do
      expect( o.community_taxon ).to eq @Calypte
      expect( @sequence[1].category ).to eq Identification::IMPROVING
      expect( @sequence[2].category ).to eq Identification::SUPPORTING
    end
    # it "should consider the identification people disagreed with to be maverick" do
    #   expect( @sequence[0].category ).to eq Identification::MAVERICK
    # end
  end
  describe "single user redundant identifications" do
    before do
      load_test_taxa
      user = User.make!
      @sequence = [
        Identification.make!( observation: o, user: user, taxon: @Calypte ),
        Identification.make!( observation: o, user: user, taxon: @Calypte )
      ]
      @sequence.each(&:reload)
    end
    it "should leave the current ID as leading" do
      expect( @sequence.last ).to be_current
      expect( @sequence.last.category ).to eq Identification::LEADING
    end
  end
  describe "disagreement within a genus" do
    before do
      load_test_taxa
      @sequence = []
      @sequence << Identification.make!( observation: o, taxon: @Calypte_anna )
      @sequence << Identification.make!( observation: o, taxon: Taxon.make!( parent: @Calypte, rank: Taxon::SPECIES ) )
      @sequence << Identification.make!( observation: o, taxon: Taxon.make!( parent: @Calypte, rank: Taxon::SPECIES ) )
      @sequence.each(&:reload)
      o.reload
      expect( o.community_taxon ).to eq @Calypte
    end
    it "should have all leading IDs" do
      expect( @sequence[0].category ).to eq Identification::LEADING
      expect( @sequence[1].category ).to eq Identification::LEADING
      expect( @sequence[2].category ).to eq Identification::LEADING
    end
  end
  describe "disagreement with revision" do
    before do
      load_test_taxa
      user = User.make!
      @sequence = []
      @sequence << Identification.make!( observation: o, taxon: @Calypte, user: user )
      @sequence << Identification.make!( observation: o, taxon: @Calypte_anna, user: user )
      @sequence << Identification.make!( observation: o, taxon: @Calypte )
      @sequence.each(&:reload)
      o.reload
      expect( o.community_taxon ).to eq @Calypte
    end
    # it "should be supporting, maverick, improving" do
    #   expect( @sequence[0].category ).to eq Identification::SUPPORTING
    #   expect( @sequence[1].category ).to eq Identification::MAVERICK
    #   expect( @sequence[2].category ).to eq Identification::IMPROVING
    # end
    it "should be improving, leading, supporting" do
      expect( @sequence[0].category ).to eq Identification::IMPROVING
      expect( @sequence[1].category ).to eq Identification::LEADING
      expect( @sequence[2].category ).to eq Identification::SUPPORTING
    end
  end
end
