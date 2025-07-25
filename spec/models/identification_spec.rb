# frozen_string_literal: true

require "spec_helper"

describe Identification, "creation" do
  describe "without callbacks" do
    it "should store the previous observation taxon" do
      o = make_research_grade_observation
      previous_observation_taxon = o.taxon
      i = Identification.make!( observation: o )
      expect( i.previous_observation_taxon ).to eq previous_observation_taxon
    end

    it "should not create a blank preference when vision is nil" do
      i = Identification.make!( vision: nil )
      expect( i.stored_preferences ).to be_blank
    end

    describe "with an inactive taxon" do
      it "should replace the taxon with its active equivalent" do
        taxon_change = make_taxon_swap
        taxon_change.committer = taxon_change.user
        taxon_change.commit
        expect( taxon_change.input_taxon ).not_to be_is_active
        expect( Identification.make!( taxon: taxon_change.input_taxon ).taxon ).to eq taxon_change.output_taxon
      end
      it "should not replace the taxon if there is no active equivalent" do
        inactive_taxon = Taxon.make!( is_active: false )
        expect( Identification.make!( taxon: inactive_taxon ).taxon ).to eq inactive_taxon
      end
      it "should not replace the taxon if there are multiple active equivalents" do
        taxon_change = make_taxon_split
        taxon_change.committer = taxon_change.user
        taxon_change.commit
        expect( taxon_change.input_taxon ).not_to be_is_active
        expect( Identification.make!( taxon: taxon_change.input_taxon ).taxon ).to eq taxon_change.input_taxon
      end
    end
  end

  describe "with callbacks" do
    it "should make older identifications not current" do
      old_ident = Identification.make!
      new_ident = Identification.make!( observation: old_ident.observation, user: old_ident.user )
      expect( new_ident ).to be_valid
      expect( new_ident ).to be_current
      old_ident.reload
      expect( old_ident ).not_to be_current
    end

    it "should not allow 2 current observations per user" do
      ident1 = Identification.make!
      ident2 = Identification.make!( user: ident1.user, observation: ident1.observation )
      ident1.reload
      ident2.reload
      expect( ident1 ).not_to be_current
      expect( ident2 ).to be_current
      ident1.update( current: true )
      ident1.reload
      ident2.reload
      expect( ident1 ).to be_current
      expect( ident2 ).not_to be_current
    end

    it "should add a taxon to its observation if it's the observer's identification" do
      obs = Observation.make!
      expect( obs.taxon_id ).to be_blank
      identification = Identification.make!( user: obs.user, observation: obs, taxon: Taxon.make! )
      obs.reload
      expect( obs.taxon_id ).to eq identification.taxon.id
    end

    it "should add a taxon to its observation if it's someone elses identification" do
      obs = Observation.make!
      expect( obs.taxon_id ).to be_blank
      expect( obs.community_taxon ).to be_blank
      identification = Identification.make!( observation: obs, taxon: Taxon.make! )
      obs.reload
      expect( obs.taxon_id ).to eq identification.taxon.id
      expect( obs.community_taxon ).to be_blank
    end

    it "shouldn't add a taxon to its observation if it's someone elses identification but the observation user rejects community IDs" do
      u = User.make!( prefers_community_taxa: false )
      obs = Observation.make!( user: u )
      expect( obs.taxon_id ).to be_blank
      expect( obs.community_taxon ).to be_blank
      Identification.make!( observation: obs, taxon: Taxon.make! )
      obs.reload
      expect( obs.taxon_id ).to be_blank
      expect( obs.community_taxon ).to be_blank
    end

    it "shouldn't create an ID by the obs owner if someone else adds an ID" do
      obs = Observation.make!
      expect( obs.taxon_id ).to be_blank
      expect( obs.identifications.count ).to eq 0
      Identification.make!( observation: obs, taxon: Taxon.make! )
      obs.reload
      expect( obs.taxon_id ).not_to be_blank
      expect( obs.identifications.count ).to eq 1
    end

    it "should not modify species_guess to an observation if there's a taxon_id and the taxon_id didn't change" do
      obs = Observation.make!
      taxon = Taxon.make!
      taxon2 = Taxon.make!
      Identification.make!(
        user: obs.user,
        observation: obs,
        taxon: taxon
      )
      obs.reload
      user = make_user_with_privilege( UserPrivilege::INTERACTION )
      Identification.make!(
        user: user,
        observation: obs,
        taxon: taxon2
      )
      obs.reload
      expect( obs.species_guess ).to eq taxon.name
    end

    it "should add a species_guess to a newly identified observation if the owner identified it and the species_guess was nil" do
      obs = Observation.make!
      taxon = Taxon.make!
      Identification.make!(
        user: obs.user,
        observation: obs,
        taxon: taxon
      )
      obs.reload
      expect( obs.species_guess ).to eq taxon.name
    end

    it "should add an iconic_taxon_id to its observation if it's the observer's identification" do
      obs = Observation.make!
      identification = Identification.make!(
        user: obs.user,
        observation: obs
      )
      obs.reload
      expect( obs.iconic_taxon_id ).to eq identification.taxon.iconic_taxon_id
    end

    it "should increment the observations num_identification_agreements if this is an agreement" do
      taxon = Taxon.make!
      obs = Observation.make!( taxon: taxon )
      old_count = obs.num_identification_agreements
      Identification.make!( observation: obs, taxon: taxon )
      obs.reload
      expect( obs.num_identification_agreements ).to eq old_count + 1
    end

    it "should increment the observation's num_identification_agreements if this is an agreement and there are outdated idents" do
      taxon = Taxon.make!
      obs = Observation.make!( taxon: taxon )
      old_ident = Identification.make!( observation: obs, taxon: taxon )
      obs.reload
      expect( obs.num_identification_agreements ).to eq( 1 )
      obs.reload
      Identification.make!( observation: obs, user: old_ident.user )
      obs.reload
      expect( obs.num_identification_agreements ).to eq( 0 )
    end

    it "should increment the observations num_identification_disagreements if this is a disagreement" do
      obs = Observation.make!( taxon: Taxon.make! )
      old_count = obs.num_identification_disagreements
      Identification.make!( observation: obs )
      obs.reload
      expect( obs.num_identification_disagreements ).to eq old_count + 1
    end

    it "should NOT increment the observations num_identification_disagreements if the obs has no taxon" do
      obs = Observation.make!
      old_count = obs.num_identification_disagreements
      Identification.make!( observation: obs )
      obs.reload
      expect( obs.num_identification_disagreements ).to eq old_count
    end

    it "should NOT increment the observations num_identification_agreements or num_identification_disagreements if theres just one ID" do
      taxon = Taxon.make!
      obs = Observation.make!
      old_agreement_count = obs.num_identification_agreements
      old_disagreement_count = obs.num_identification_disagreements
      expect( obs.community_taxon ).to be_blank
      Identification.make!( observation: obs, taxon: taxon )
      obs.reload
      expect( obs.num_identification_agreements ).to eq old_agreement_count
      expect( obs.num_identification_disagreements ).to eq old_disagreement_count
      expect( obs.community_taxon ).to be_blank
      expect( obs.identifications.count ).to eq 1
    end

    it "should consider an identification with a taxon that is a child of " \
      "the observation's taxon to be in agreement" do
      taxon = Taxon.make!( rank: Taxon::SPECIES )
      parent = Taxon.make!( rank: Taxon::GENUS )
      taxon.update( parent: parent )
      observation = Observation.make!( taxon: parent, prefers_community_taxon: false )
      identification = Identification.make!( observation: observation, taxon: taxon )
      expect( identification.user ).not_to be( identification.observation.user )
      expect( identification.is_agreement? ).to be true
    end

    it "should not consider an identification with a taxon that is a parent " \
      "of the observation's taxon to be in agreement" do
      taxon = Taxon.make!
      parent = Taxon.make!
      taxon.update( parent: parent )
      observation = Observation.make!( taxon: taxon, prefers_community_taxon: false )
      identification = Identification.make!( observation: observation, taxon: parent )
      expect( identification.user ).not_to be( identification.observation.user )
      expect( identification.is_agreement? ).to be false
    end

    it "should not consider identifications of different taxa in the different lineages to be in agreement" do
      taxon = Taxon.make!( rank: Taxon::GENUS )
      child = Taxon.make!( parent: taxon, rank: Taxon::SPECIES )
      o = Observation.make!( prefers_community_taxon: false )
      Identification.make!( taxon: child, observation: o )
      disagreement = Identification.make!( observation: o, taxon: taxon )
      expect( disagreement.is_agreement? ).to be false
    end

    it "should update observation quality_grade" do
      o = make_research_grade_candidate_observation( taxon: Taxon.make!( rank: Taxon::SPECIES ) )
      expect( o.quality_grade ).to eq Observation::NEEDS_ID
      Identification.make!( observation: o, taxon: o.taxon )
      o.reload
      expect( o.quality_grade ).to eq Observation::RESEARCH_GRADE
    end

    it "should trigger setting a taxon photo if obs became research grade" do
      t = Taxon.make!( rank: Taxon::SPECIES )
      o = make_research_grade_candidate_observation
      expect( o ).not_to be_research_grade
      expect( t.photos.size ).to eq 0
      without_delay do
        Identification.make!( observation: o, taxon: t )
        Identification.make!( observation: o, taxon: t )
      end
      o.reload
      t.reload
      expect( o ).to be_research_grade
      expect( t.photos.size ).to eq 1
    end

    it "should not trigger setting a taxon photo if obs was already research grade" do
      o = without_delay { make_research_grade_observation }
      o.taxon.taxon_photos.delete_all
      expect( o.taxon.photos.count ).to eq 0
      without_delay { Identification.make!( observation: o, taxon: o.taxon ) }
      o.reload
      expect( o.taxon.photos.count ).to eq 0
    end

    it "should not trigger setting a taxon photo if taxon already has a photo" do
      t = Taxon.make!( rank: Taxon::SPECIES )
      t.photos << LocalPhoto.make!
      o = make_research_grade_candidate_observation
      expect( o ).not_to be_research_grade
      expect( t.photos.size ).to eq 1
      without_delay do
        Identification.make!( observation: o, taxon: t )
        Identification.make!( observation: o, taxon: t )
      end
      o.reload
      t.reload
      expect( o ).to be_research_grade
      expect( t.photos.size ).to eq 1
    end

    it "should update observation quality grade after disagreement when observer opts out of CID" do
      g = create :taxon, :as_genus
      s1 = create :taxon, :as_species, parent: g
      s2 = create :taxon, :as_species, parent: g
      o = make_research_grade_observation( prefers_community_taxon: false, taxon: s1 )
      expect( o ).to be_research_grade
      2.times { create( :identification, observation: o, taxon: s2 ) }
      o.reload
      expect( o ).not_to be_research_grade
      o.owners_identification.destroy
      o.reload
      expect( o.owners_identification ).to be_blank
      create( :identification, user: o.user, observation: o, taxon: s2 )
      o.reload
      expect( o ).to be_research_grade
    end

    it "should obscure the observation's coordinates if the taxon is threatened" do
      o = Observation.make!( latitude: 1, longitude: 1 )
      expect( o ).not_to be_coordinates_obscured
      Identification.make!( taxon: make_threatened_taxon, observation: o, user: o.user )
      o.reload
      expect( o ).to be_coordinates_obscured
    end

    it "should set the observation's community taxon" do
      t = Taxon.make!
      o = Observation.make!( taxon: t )
      expect( o.community_taxon ).to be_blank
      Identification.make!( observation: o, taxon: t )
      o.reload
      expect( o.community_taxon ).to eq( t )
    end

    it "should touch the observation" do
      o = Observation.make!
      updated_at_was = o.updated_at
      Identification.make!( observation: o, user: o.user )
      o.reload
      expect( updated_at_was ).to be < o.updated_at
    end

    it "creates observation reviews if they dont exist" do
      o = Observation.make!
      expect( o.observation_reviews.count ).to eq 0
      Identification.make!( observation: o, user: o.user )
      o.reload
      expect( o.observation_reviews.count ).to eq 1
    end

    it "updates existing reviews" do
      o = Observation.make!
      r = ObservationReview.make!( observation: o, user: o.user, updated_at: 1.day.ago )
      Identification.make!( observation: o, user: o.user )
      o.reload
      expect( o.observation_reviews.first ).to eq r
      expect( o.observation_reviews.first.updated_at ).to be > r.updated_at
    end

    it "marks existing unreviewed reviews as reviewed" do
      o = Observation.make!
      r = ObservationReview.make!( observation: o, user: o.user )
      r.update( reviewed: false )
      Identification.make!( observation: o, user: o.user )
      o.reload
      expect( o.observation_reviews.first ).to eq r
      expect( o.observation_reviews.first ).to be_reviewed
    end

    it "should set curator_identification_id on project observations to last current identification" do
      o = Observation.make!
      p = Project.make!
      ProjectUser.make!( user: o.user, project: p )
      po = ProjectObservation.make!( observation: o, project: p )
      i1 = Identification.make!( user: p.user, observation: o )
      Delayed::Worker.new.work_off
      po.reload
      expect( po.curator_identification_id ).to eq i1.id
    end

    it "should set the observation's taxon_geoprivacy if taxon was threatened" do
      t = make_threatened_taxon
      o = Observation.make!
      expect( o.taxon_geoprivacy ).to be_blank
      Identification.make!( taxon: t, observation: o )
      o.reload
      expect( o.taxon_geoprivacy ).to eq Observation::OBSCURED
    end

    it "should make the observation casual if the observer has opted out and their ID is now maverick" do
      f = create :taxon, :as_family
      g = create :taxon, :as_genus, parent: f
      sp1 = create :taxon, :as_species, parent: g
      sp2 = create :taxon, :as_species, parent: g
      o = make_research_grade_candidate_observation( taxon: sp1, prefers_community_taxon: false )
      expect( o.quality_grade ).to eq Observation::NEEDS_ID
      _id1 = create :identification, observation: o, taxon: sp2
      expect( o.quality_grade ).to eq Observation::NEEDS_ID
      _id2 = create :identification, observation: o, taxon: sp2
      expect( o.quality_grade ).to eq Observation::NEEDS_ID
      puts "adding final ident"
      _id3 = create :identification, observation: o, taxon: sp2
      puts "added final ident"
      o.reload
      expect( o.owners_identification.category ).to eq Identification::MAVERICK
      expect( o.quality_grade ).to eq Observation::CASUAL
    end

    describe "with indexing" do
      elastic_models( Observation, Identification )

      it "should make older identifications not current in elasticsearch" do
        old_ident = Identification.make!
        without_delay do
          Identification.make!( observation: old_ident.observation, user: old_ident.user )
        end
        es_response = Identification.elastic_search( where: { id: old_ident.id } ).results.results.first
        expect( es_response.id.to_s ).to eq old_ident.id.to_s
        old_ident.reload
        expect( old_ident ).not_to be_current
        expect( es_response.current ).to be false
      end

      it "does not revert observation quality_grade changes made elsewhere" do
        observation = make_research_grade_observation
        # load the observation with its quality_metrics association to set up conditions for
        # the race condition we want to test
        observation = Observation.where( id: observation.id ).includes( :quality_metrics ).first
        expect( observation.quality_grade ).to eq Observation::RESEARCH_GRADE

        # simulate creating a quality metric during identification creation, setting up the race
        QualityMetric.make!( observation: observation, metric: QualityMetric::WILD, agree: false )
        expect( Observation.find( observation.id ).quality_grade ).to eq Observation::CASUAL
        expect( QualityMetric.where( observation: observation ).count ).to eq 1

        # check that the obervation quality grade and quality metrics still represent the state
        # before the quality metric was added
        expect( observation.quality_grade ).to eq Observation::RESEARCH_GRADE
        expect( observation.quality_metrics.size ).to eq 0

        # create the identification with the cached observation and check its quality grade
        # will ultimately be updated to reflect the quality_metric added externally
        Identification.make!( observation: observation, taxon: observation.taxon )
        expect( observation.quality_grade ).to eq Observation::CASUAL
      end

      describe "user counter cache" do
        it "should incremement for an ident on someone else's observation, with delay" do
          taxon = Taxon.make!
          obs = Observation.make!( taxon: taxon )
          user = make_user_with_privilege( UserPrivilege::INTERACTION )
          Delayed::Job.destroy_all
          expect( Delayed::Job.count ).to eq 0
          expect( user.identifications_count ).to eq 0
          Identification.make!( user: user, observation: obs, taxon: taxon )
          expect( Delayed::Job.count ).to be > 1
          user.reload
          expect( user.identifications_count ).to eq 0
          Delayed::Job.all.each {| j | Delayed::Worker.new.run( j ) }
          user.reload
          expect( user.identifications_count ).to eq 1
        end

        it "should NOT incremement for an ident on one's OWN observation" do
          user = User.make!
          obs = Observation.make!( user: user )
          expect do
            without_delay { Identification.make!( user: user, observation: obs ) }
          end.to_not change( user, :identifications_count )
        end
      end

      describe "with notifications" do
        before { enable_has_subscribers }
        after { disable_has_subscribers }

        it "notifies the observer" do
          o = create :observation
          expect( o.user.recent_notifications.detect {| ua | ua.resource == o } ).to be_blank
          after_delayed_job_finishes( ignore_run_at: true ) do
            create :identification, observation: o
          end
          expect( o.user.recent_notifications.detect {| ua | ua.resource == o } ).not_to be_blank
        end

        it "notifies other identifiers" do
          i = create :identification
          expect( i.user.recent_notifications.detect {| ua | ua.resource == i.observation } ).to be_blank
          after_delayed_job_finishes( ignore_run_at: true ) do
            create :identification, observation: i.observation
          end
          expect( i.user.recent_notifications.detect {| ua | ua.resource == i.observation } ).not_to be_blank
        end

        let( :genus ) { create :taxon, :as_genus }
        let( :species ) { create :taxon, :as_species, parent: genus }
        let( :subspecies ) { create :taxon, :as_subspecies, parent: species }

        describe "when subscriber doesn't prefers_redundant_identification_notifications" do
          let( :subscriber ) { create :user, prefers_redundant_identification_notifications: false }
          it "notifies when taxon is an ancestor of the subscriber's identification taxon" do
            subscribers_ident = create :identification, user: subscriber, taxon: species
            obs = subscribers_ident.observation
            expect( subscriber.recent_notifications.detect {| ua | ua.resource == obs } ).to be_blank
            after_delayed_job_finishes( ignore_run_at: true ) do
              _other_ident = create :identification, observation: obs, taxon: genus
            end
            expect( subscriber.recent_notifications.detect {| ua | ua.resource == obs } ).not_to be_blank
          end

          it "notifies when taxon is a descendant of the subscriber's identification taxon" do
            subscribers_ident = create :identification, user: subscriber, taxon: genus
            obs = subscribers_ident.observation
            expect( subscriber.recent_notifications.detect {| ua | ua.resource == obs } ).to be_blank
            after_delayed_job_finishes( ignore_run_at: true ) do
              _other_ident = create :identification, observation: obs, taxon: species
            end
            expect( subscriber.recent_notifications.detect {| ua | ua.resource == obs } ).not_to be_blank
          end

          it "does not notify when taxon does match the subscriber's identification taxon" do
            subscribers_ident = create :identification, user: subscriber, taxon: genus
            obs = subscribers_ident.observation
            expect( subscriber.recent_notifications.detect {| ua | ua.resource == obs } ).to be_blank
            after_delayed_job_finishes( ignore_run_at: true ) do
              _other_ident = create :identification, observation: obs, taxon: genus
            end
            expect( subscriber.recent_notifications.detect {| ua | ua.resource == obs } ).to be_blank
          end
        end

        describe "when subscriber doesn't prefers_infraspecies_identification_notifications" do
          let( :subscriber ) { create :user, prefers_infraspecies_identification_notifications: false }
          it "notifies when taxon is a species" do
            subscribers_ident = create :identification, user: subscriber, taxon: genus
            obs = subscribers_ident.observation
            expect( subscriber.recent_notifications.detect {| ua | ua.resource == obs } ).to be_blank
            after_delayed_job_finishes( ignore_run_at: true ) do
              _other_ident = create :identification, observation: obs, taxon: species
            end
            expect( subscriber.recent_notifications.detect {| ua | ua.resource == obs } ).not_to be_blank
          end

          it "does not notify when taxon is a subspecies" do
            subscribers_ident = create :identification, user: subscriber, taxon: species
            obs = subscribers_ident.observation
            expect( subscriber.recent_notifications.detect {| ua | ua.resource == obs } ).to be_blank
            after_delayed_job_finishes( ignore_run_at: true ) do
              _other_ident = create :identification, observation: obs, taxon: subspecies
            end
            expect( subscriber.recent_notifications.detect {| ua | ua.resource == obs } ).to be_blank
          end

          it "does notify when taxon is a subspecies but body present" do
            subscribers_ident = create :identification, user: subscriber, taxon: species
            obs = subscribers_ident.observation
            expect( subscriber.recent_notifications.detect {| ua | ua.resource == obs } ).to be_blank
            other_ident = after_delayed_job_finishes( ignore_run_at: true ) do
              create :identification, observation: obs, taxon: subspecies, body: Faker::Lorem.sentence
            end
            expect( other_ident.body ).to be_present
            expect( subscriber.recent_notifications.detect {| ua | ua.resource == obs } ).to be_present
          end

          it "does notify when taxon is a subspecies on a different branch than the subscriber's taxon" do
            other_species = create :taxon, :as_species, parent: genus
            other_subspecies = create :taxon, :as_subspecies, parent: other_species
            subscribers_ident = create :identification, user: subscriber, taxon: species
            obs = subscribers_ident.observation
            expect( subscriber.recent_notifications.detect {| ua | ua.resource == obs } ).to be_blank
            after_delayed_job_finishes( ignore_run_at: true ) do
              _other_ident = create :identification, observation: obs, taxon: other_subspecies
            end
            expect( subscriber.recent_notifications.detect {| ua | ua.resource == obs } ).to be_present
          end

          it "does notify when taxon is a subspecies sister to the subscriber's taxon" do
            sister_subspecies = create :taxon, :as_subspecies, parent: species
            subscribers_ident = create :identification, user: subscriber, taxon: subspecies
            obs = subscribers_ident.observation
            expect( subscriber.recent_notifications.detect {| ua | ua.resource == obs } ).to be_blank
            after_delayed_job_finishes( ignore_run_at: true ) do
              _other_ident = create :identification, observation: obs, taxon: sister_subspecies
            end
            expect( subscriber.recent_notifications.detect {| ua | ua.resource == obs } ).to be_present
          end

          it "does notify when taxon is a subspecies and the subsriber's is a genus" do
            subscribers_ident = create :identification, user: subscriber, taxon: genus
            obs = subscribers_ident.observation
            expect( subscriber.recent_notifications.detect {| ua | ua.resource == obs } ).to be_blank
            after_delayed_job_finishes( ignore_run_at: true ) do
              _other_ident = create :identification, observation: obs, taxon: subspecies
            end
            expect( subscriber.recent_notifications.detect {| ua | ua.resource == obs } ).to be_present
          end
        end

        describe "when subscriber doesn't prefers_non_disagreeing_identification_notifications" do
          let( :subscriber ) { create :user, prefers_non_disagreeing_identification_notifications: false }
          it "notifies when taxon descends from subscriber's taxon" do
            subscribers_ident = create :identification, user: subscriber, taxon: genus
            obs = subscribers_ident.observation
            expect( subscriber.recent_notifications.detect {| ua | ua.resource == obs } ).to be_blank
            after_delayed_job_finishes( ignore_run_at: true ) do
              create :identification, observation: obs, taxon: species
            end
            expect( subscriber.recent_notifications.detect {| ua | ua.resource == obs } ).to be_present
          end

          it "notifies when taxon is ancestor disagreement with subscriber's taxon" do
            obs = create :observation, user: subscriber, taxon: species
            subscribers_ident = obs.identifications.detect {| ident | ident.user_id == subscriber.id }
            expect( subscribers_ident.taxon ).to eq species
            expect( subscriber.recent_notifications.detect {| ua | ua.resource == obs } ).to be_blank
            after_delayed_job_finishes( ignore_run_at: true ) do
              create :identification, observation: obs, taxon: genus, disagreement: true
            end
            expect( subscriber.recent_notifications.detect {| ua | ua.resource == obs } ).to be_present
          end

          it "notifies when taxon is on a different branch from subscriber's taxon" do
            other_species = create :taxon, :as_species, parent: genus
            subscribers_ident = create :identification, user: subscriber, taxon: species
            obs = subscribers_ident.observation
            expect( subscriber.recent_notifications.detect {| ua | ua.resource == obs } ).to be_blank
            after_delayed_job_finishes( ignore_run_at: true ) do
              create :identification, observation: obs, taxon: other_species
            end
            expect( subscriber.recent_notifications.detect {| ua | ua.resource == obs } ).to be_present
          end

          it "does not notify when taxon is an ancestor of subscriber's taxon but ident is not disagreement" do
            obs = create :observation, user: subscriber, taxon: species
            subscribers_ident = obs.identifications.detect {| ident | ident.user_id == subscriber.id }
            expect( subscribers_ident.taxon ).to eq species
            expect( subscriber.recent_notifications.detect {| ua | ua.resource == obs } ).to be_blank
            other_ident = after_delayed_job_finishes( ignore_run_at: true ) do
              create :identification, observation: obs, taxon: genus, disagreement: false
            end
            expect( other_ident ).not_to be_disagreement
            expect( subscriber.recent_notifications.detect {| ua | ua.resource == obs } ).to be_blank
          end
        end
      end
    end
  end
end

describe Identification, "updating" do
  it "should not change current status of other identifications" do
    i1 = Identification.make!
    i2 = Identification.make!( observation: i1.observation, user: i1.user )
    i1.reload
    i2.reload
    expect( i1 ).not_to be_current
    expect( i2 ).to be_current
    i1.update( body: "foo" )
    i1.reload
    i2.reload
    expect( i1 ).not_to be_current
    expect( i2 ).to be_current
  end

  describe "observation taxon_geoprivacy" do
    it "should change if becomes current" do
      threatened = make_threatened_taxon( rank: Taxon::SPECIES )
      not_threatened = Taxon.make!( rank: Taxon::SPECIES )
      o = Observation.make!( taxon: threatened )
      i1 = o.identifications.first
      o.reload
      expect( o.taxon_geoprivacy ).to eq Observation::OBSCURED
      Identification.make!( user: i1.user, observation: o, taxon: not_threatened )
      o.reload
      expect( o.taxon_geoprivacy ).to be_blank
      i1.reload
      i1.update( current: true )
      o.reload
      expect( o.taxon_geoprivacy ).to eq Observation::OBSCURED
    end
  end
end

describe Identification, "deletion" do
  it "should remove the taxon associated with the observation if it's the observer's identification and obs does not prefers_community_taxon" do
    observation = Observation.make!( taxon: Taxon.make!, prefers_community_taxon: false )
    Identification.make!( observation: observation, taxon: observation.taxon )
    expect( observation.taxon ).not_to be_blank
    expect( observation ).to be_valid
    expect( observation.identifications.length ).to be >= 1
    doomed_ident = observation.identifications.select do | ident |
      ident.user_id == observation.user_id
    end.first
    expect( doomed_ident.user_id ).to eq observation.user_id
    doomed_ident.destroy
    observation.reload
    expect( observation.taxon_id ).to be_blank
  end

  it "should NOT remove the taxon associated with the observation if it's the observer's identification and obs prefers_community_taxon " do
    observation_prefers_community_taxon = Observation.make!( taxon: Taxon.make! )
    Identification.make!(
      observation: observation_prefers_community_taxon,
      taxon: observation_prefers_community_taxon.taxon
    )
    expect( observation_prefers_community_taxon.taxon ).not_to be_nil
    expect( observation_prefers_community_taxon ).to be_valid
    observation_prefers_community_taxon.reload
    expect( observation_prefers_community_taxon.identifications.length ).to be >= 1
    doomed_ident = observation_prefers_community_taxon.identifications.select do | ident |
      ident.user_id == observation_prefers_community_taxon.user_id
    end.first
    expect( doomed_ident.user_id ).to eq observation_prefers_community_taxon.user_id
    doomed_ident.destroy
    observation_prefers_community_taxon.reload
    expect( observation_prefers_community_taxon.taxon_id ).not_to be_nil
  end

  it "should decrement the observation's num_identification_agreements if this was an agreement" do
    o = Observation.make!( taxon: Taxon.make! )
    i = Identification.make!( observation: o, taxon: o.taxon )
    expect( o.num_identification_agreements ).to eq 1
    i.destroy
    o.reload
    expect( o.num_identification_agreements ).to eq 0
  end

  it "should decrement the observations num_identification_disagreements if this was a disagreement" do
    o = Observation.make!( taxon: Taxon.make! )
    ident = Identification.make!( observation: o )
    o.reload
    expect( o.num_identification_disagreements ).to be >= 1
    num_identification_disagreements = o.num_identification_disagreements
    ident.destroy
    o.reload
    expect( o.num_identification_disagreements ).to eq num_identification_disagreements - 1
  end

  it "should decremement the counter cache in users for an ident on someone else's observation" do
    i = Identification.make!
    expect( i.user ).not_to be i.observation.user
    i.user.identifications_count
    user = i.user
    i.destroy
    user.reload
    expect( user.identifications_count ).to eq 0
  end

  it "should NOT decremement the counter cache in users for an ident on one's OWN observation" do
    new_observation = Observation.make!( taxon: Taxon.make! )
    new_observation.reload
    owners_ident = new_observation.identifications.select do | ident |
      ident.user_id == new_observation.user_id
    end.first
    user = new_observation.user
    old_count = user.identifications_count
    owners_ident.destroy
    user.reload
    expect( user.identifications_count ).to eq old_count
  end

  it "should update observation quality_grade" do
    o = make_research_grade_observation
    expect( o.quality_grade ).to eq Observation::RESEARCH_GRADE
    o.identifications.last.destroy
    o.reload
    expect( o.quality_grade ).to eq Observation::NEEDS_ID
  end

  it "should update observation quality_grade if made by another user" do
    o = make_research_grade_observation
    expect( o.quality_grade ).to eq Observation::RESEARCH_GRADE
    o.identifications.each {| ident | ident.destroy if ident.user_id != o.user_id }
    o.reload
    expect( o.quality_grade ).to eq Observation::NEEDS_ID
  end

  it "should not queue a job to update project lists if owners ident" do
    o = make_research_grade_observation
    Delayed::Job.delete_all
    stamp = Time.now
    o.owners_identification.destroy
    Delayed::Job.delete_all

    Identification.make!( user: o.user, observation: o, taxon: Taxon.make! )
    jobs = Delayed::Job.where( "created_at >= ?", stamp )

    pattern = /ProjectList.*refresh_with_observation/m
    job = jobs.detect {| j | j.handler =~ pattern }
    expect( job ).to be_blank
    # puts job.handler.inspect
  end

  it "should update check lists if changed from research grade" do
    o = make_research_grade_observation
    Delayed::Job.delete_all

    expect( o ).to receive( :refresh_check_lists ).at_least( :once )
    o.identifications.by( o.user ).first.destroy
  end

  it "should queue a job to update check lists if research grade" do
    o = make_research_grade_observation
    o.identifications.each {| ident | ident.destroy if ident.user_id != o.user_id }
    o.reload
    expect( o.quality_grade ).to eq Observation::NEEDS_ID

    expect( o ).to receive( :refresh_check_lists ).at_least( :once )
    Identification.make!( taxon: o.taxon, observation: o )
    expect( o.quality_grade ).to eq Observation::RESEARCH_GRADE
  end

  it "should nilify curator_identification_id on project observations if no other current identification" do
    o = Observation.make!
    p = Project.make!
    ProjectUser.make!( user: o.user, project: p )
    po = ProjectObservation.make!( observation: o, project: p )
    i = Identification.make!( user: p.user, observation: o )
    Identification.run_update_curator_identification( i )
    po.reload
    expect( po.curator_identification ).not_to be_blank
    expect( po.curator_identification_id ).to eq i.id
    i.destroy
    po.reload
    expect( po.curator_identification_id ).to be_blank
  end

  it "should set curator_identification_id on project observations to last current identification" do
    o = Observation.make!
    p = Project.make!
    ProjectUser.make!( user: o.user, project: p )
    po = ProjectObservation.make!( observation: o, project: p )
    i1 = Identification.make!( user: p.user, observation: o )
    Identification.run_update_curator_identification( i1 )
    i2 = Identification.make!( user: p.user, observation: o )
    Identification.run_update_curator_identification( i2 )
    po.reload
    expect( po.curator_identification_id ).to eq i2.id
    i2.destroy
    Identification.run_revisit_curator_identification( o.id, i2.user_id )
    po.reload
    expect( po.curator_identification_id ).to eq i1.id
  end

  it "should set the user's last identification as current" do
    ident1 = Identification.make!
    ident2 = Identification.make!( observation: ident1.observation, user: ident1.user )
    ident3 = Identification.make!( observation: ident1.observation, user: ident1.user )
    ident2.reload
    expect( ident2 ).not_to be_current
    ident3.destroy
    ident2.reload
    expect( ident2 ).to be_current
    ident1.reload
    expect( ident1 ).not_to be_current
  end

  it "should set observation taxon to that of last current ident for owner" do
    o = Observation.make!( taxon: Taxon.make! )
    o.owners_identification
    ident2 = Identification.make!( observation: o, user: o.user )
    ident3 = Identification.make!( observation: o, user: o.user )
    o.reload
    expect( o.taxon_id ).to eq( ident3.taxon_id )
    ident3.destroy
    o.reload
    expect( o.taxon_id ).to eq( ident2.taxon_id )
  end

  it "should set the observation's community taxon if remaining identifications" do
    load_test_taxa
    o = Observation.make!( taxon: @Calypte_anna )
    expect( o.community_taxon ).to be_blank
    i1 = Identification.make!( observation: o, taxon: @Calypte_anna )
    Identification.make!( observation: o, taxon: @Calypte_anna )
    Identification.make!( observation: o, taxon: @Pseudacris_regilla )
    o.reload
    expect( o.community_taxon ).to eq( @Calypte_anna )
    i1.destroy
    o.reload
    expect( o.community_taxon ).to eq( @Chordata ) # consensus
  end

  it "should remove the observation's community taxon if no more identifications" do
    o = Observation.make!( taxon: Taxon.make! )
    i = Identification.make!( observation: o, taxon: o.taxon )
    o.reload
    expect( o.community_taxon ).to eq o.taxon
    i.destroy
    o.reload
    expect( o.community_taxon ).to be_blank
  end

  it "should remove the observation.taxon if there are no more identifications" do
    o = Observation.make!
    i = Identification.make!( observation: o )
    expect( o.taxon ).to eq i.taxon
    i.destroy
    o.reload
    expect( o.taxon ).to be_blank
  end

  it "destroys automatically created reviews" do
    o = Observation.make!
    i = Identification.make!( observation: o, user: o.user )
    expect( o.observation_reviews.count ).to eq 1
    i.destroy
    o.reload
    expect( o.observation_reviews.count ).to eq 0
  end

  it "does not destroy user created reviews" do
    o = Observation.make!
    i = Identification.make!( observation: o, user: o.user )
    o.observation_reviews.destroy_all
    ObservationReview.make!( observation: o, user: o.user, user_added: true )
    expect( o.observation_reviews.count ).to eq 1
    i.destroy
    o.reload
    expect( o.observation_reviews.count ).to eq 1
  end
end

describe Identification, "captive" do
  elastic_models( Observation, Identification )

  it "should vote yes on the wild quality metric if 1" do
    i = Identification.make!( captive_flag: "1" )
    o = i.observation
    expect( o.quality_metrics ).not_to be_blank
    expect( o.quality_metrics.first.user ).to eq( i.user )
    expect( o.quality_metrics.first ).not_to be_agree
  end

  it "should vote no on the wild quality metric if 0 and metric exists" do
    i = Identification.make!( captive_flag: "1" )
    o = i.observation
    expect( o.quality_metrics ).not_to be_blank
    i.update( captive_flag: "0" )
    o.reload
    expect( o.quality_metrics.first ).not_to be_agree
  end

  it "should not alter quality metrics if nil" do
    i = Identification.make!( captive_flag: nil )
    o = i.observation
    expect( o.quality_metrics ).to be_blank
  end

  it "should not alter quality metrics if 0 and not metrics exist" do
    i = Identification.make!( captive_flag: "0" )
    o = i.observation
    expect( o.quality_metrics ).to be_blank
  end
end

describe Identification do
  elastic_models( Observation, Identification )

  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to :taxon_change }
  it { is_expected.to belong_to( :previous_observation_taxon ).class_name "Taxon" }
  it {
    is_expected.to have_many( :project_observations ).with_foreign_key( :curator_identification_id ).dependent :nullify
  }

  it { is_expected.to validate_presence_of :observation }
  it { is_expected.to validate_presence_of :user }
  it { is_expected.to validate_presence_of( :taxon ).with_message "for an ID must be something we recognize" }
  it {
    is_expected.to validate_length_of( :body ).is_at_least( 0 ).is_at_most( Comment::MAX_LENGTH ).allow_blank.on :create
  }

  describe "mentions" do
    before { enable_has_subscribers }
    after { disable_has_subscribers }

    it "knows what users have been mentioned" do
      u = User.make!
      i = Identification.make!( body: "hey @#{u.login}" )
      expect( i.mentioned_users ).to eq [u]
    end

    it "generates mention updates" do
      u = User.make!
      expect( UpdateAction.unviewed_by_user_from_query( u.id, notification: "mention" ) ).to eq false
      Identification.make!( body: "hey @#{u.login}" )
      expect( UpdateAction.unviewed_by_user_from_query( u.id, notification: "mention" ) ).to eq true
    end
  end

  describe "update_curator_identification" do
    it "does not queue a job if an observation has no project_observations" do
      observation = Observation.make!
      expect( Delayed::Job.where( "handler LIKE '%run_update_curator_identification%'" ) ).to be_empty
      Identification.make!( observation: observation )
      expect( Delayed::Job.where( "handler LIKE '%run_update_curator_identification%'" ) ).to be_empty
    end

    it "does queue a job if an observation has project_observations" do
      observation = Observation.make!
      ProjectObservation.make!( observation: observation )
      expect( Delayed::Job.where( "handler LIKE '%run_update_curator_identification%'" ) ).to be_empty
      Identification.make!( observation: observation )
      expect( Delayed::Job.where( "handler LIKE '%run_update_curator_identification%'" ) ).not_to be_empty
    end
  end

  describe "run_update_curator_identification" do
    it "indexes the observation in elasticsearch" do
      o = Observation.make!
      p = Project.make!
      ProjectUser.make!( user: o.user, project: p )
      ProjectObservation.make!( observation: o, project: p )
      i = Identification.make!( user: p.user, observation: o )
      expect( Observation.page_of_results( project_id: p.id, pcid: true ).
        total_entries ).to eq 0
      Identification.run_update_curator_identification( i )
      expect( Observation.page_of_results( project_id: p.id, pcid: true ).
        total_entries ).to eq 1
    end
  end
end

describe Identification, "category" do
  let( :o ) { Observation.make! }
  let( :parent ) { Taxon.make!( rank: Taxon::GENUS ) }
  let( :child ) { Taxon.make!( rank: Taxon::SPECIES, parent: parent ) }
  describe "should be improving when" do
    it "is the first that matches the community ID among several IDs" do
      i1 = Identification.make!( observation: o )
      Identification.make!( observation: o, taxon: i1.taxon )
      o.reload
      i1.reload
      expect( o.community_taxon ).to eq i1.taxon
      expect( i1.observation.identifications.count ).to eq 2
      expect( i1.category ).to eq Identification::IMPROVING
    end
    it "qualifies but isn't current" do
      i1 = Identification.make!( observation: o, taxon: parent )
      Identification.make!( observation: o, taxon: child )
      i1.reload
      expect( i1.category ).to eq Identification::IMPROVING
      Identification.make!( observation: o, taxon: child, user: i1.user )
      i1.reload
      expect( i1.category ).to eq Identification::IMPROVING
    end
    it "is an ancestor of the community taxon and was not added after the first ID of the community taxon" do
      i1 = Identification.make!( observation: o, taxon: parent )
      Identification.make!( observation: o, taxon: child )
      Identification.make!( observation: o, taxon: child )
      Identification.make!( observation: o, taxon: child )
      o.reload
      expect( o.community_taxon ).to eq child
      i1.reload
      expect( i1.category ).to eq Identification::IMPROVING
    end
  end
  describe "should be maverick when" do
    it "the community taxon is not an ancestor" do
      i1 = Identification.make!( observation: o )
      Identification.make!( observation: o, taxon: i1.taxon )
      i3 = Identification.make!( observation: o )
      i3.reload
      expect( i3.category ).to eq Identification::MAVERICK
    end
  end
  describe "should be leading when" do
    it "is the only ID" do
      i = Identification.make!
      expect( i.category ).to eq Identification::LEADING
    end
    it "has a taxon that is a descendant of the community taxon" do
      Identification.make!( observation: o, taxon: parent )
      Identification.make!( observation: o, taxon: parent )
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
      Identification.make!( observation: o, taxon: parent )
      Identification.make!( observation: o, taxon: child )
      i3 = Identification.make!( observation: o, taxon: child )
      expect( i3.category ).to eq Identification::SUPPORTING
    end
  end
  describe "examples: " do
    describe "sequence of IDs along the same ancestry" do
      before do
        load_test_taxa
        @sequence = [
          Identification.make!( observation: o, taxon: @Chordata ),
          Identification.make!( observation: o, taxon: @Aves ),
          Identification.make!( observation: o, taxon: @Calypte ),
          Identification.make!( observation: o, taxon: @Calypte_anna )
        ]
        @sequence.each( &:reload )
        @sequence
      end
      it "should all be improving until the community taxon" do
        o.reload
        expect( o.community_taxon ).to eq @Calypte
        expect( @sequence[0].category ).to eq Identification::IMPROVING
        expect( @sequence[1].category ).to eq Identification::IMPROVING
      end
      it "should be improving when it's the first to match the community ID" do
        expect( @sequence[2].category ).to eq Identification::IMPROVING
      end
      it "should end with a leading ID" do
        expect( @sequence.last.category ).to eq Identification::LEADING
      end
      it "should continue to have improving IDs even if the first identifier agrees with the last" do
        first = @sequence[0]
        Identification.make!( observation: o, taxon: @sequence[-1].taxon, user: first.user )
        first.reload
        @sequence[1].reload
        expect( first ).not_to be_current
        expect( first.category ).to eq Identification::IMPROVING
        expect( @sequence[1].category ).to eq Identification::IMPROVING
      end
    end
  end
  describe "after withdrawing and restoring" do
    before do
      load_test_taxa
      u1 = o.user
      u2 = make_user_with_privilege( UserPrivilege::INTERACTION )
      @sequence = [
        Identification.make!( observation: o, taxon: @Calypte_anna, user: u1 ),
        Identification.make!( observation: o, taxon: @Calypte, user: u1 ),
        Identification.make!( observation: o, taxon: @Calypte, user: u2 ),
        Identification.make!( observation: o, taxon: @Calypte_anna, user: u1 )
      ]
      @sequence.each( &:reload )
      o.reload
      @sequence
    end
    it "should not change" do
      expect( o.community_taxon ).to eq @Calypte
      expect( @sequence[2].category ).to eq Identification::SUPPORTING
      @sequence[2].update( current: false )
      expect( @sequence[2] ).not_to be_current
      @sequence[2].update( current: true )
      @sequence[2].reload
      expect( @sequence[2].category ).to eq Identification::SUPPORTING
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
      @sequence.each( &:reload )
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
      user = make_user_with_privilege( UserPrivilege::INTERACTION )
      @sequence = [
        Identification.make!( observation: o, user: user, taxon: @Calypte ),
        Identification.make!( observation: o, user: user, taxon: @Calypte )
      ]
      @sequence.each( &:reload )
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
      @sequence.each( &:reload )
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
      user = make_user_with_privilege( UserPrivilege::INTERACTION )
      @sequence = []
      @sequence << Identification.make!( observation: o, taxon: @Calypte, user: user )
      @sequence << Identification.make!( observation: o, taxon: @Calypte_anna, user: user )
      @sequence << Identification.make!( observation: o, taxon: @Calypte )
      @sequence.each( &:reload )
      o.reload
      expect( o.community_taxon ).to eq @Calypte
    end
    it "should be improving, leading, supporting" do
      expect( @sequence[0].category ).to eq Identification::IMPROVING
      expect( @sequence[1].category ).to eq Identification::LEADING
      expect( @sequence[2].category ).to eq Identification::SUPPORTING
    end
  end
  describe "after taxon swap" do
    let( :swap ) { make_taxon_swap }
    let( :o ) { make_research_grade_observation( taxon: swap.input_taxon ) }
    it "should be improving, supporting for acitve IDs" do
      expect( o.identifications.sort_by( &:id )[0].category ).to eq Identification::IMPROVING
      expect( o.identifications.sort_by( &:id )[1].category ).to eq Identification::SUPPORTING
      swap.committer = swap.user
      swap.commit
      Delayed::Worker.new.work_off
      o.reload
      expect( o.identifications.sort_by( &:id )[2].category ).to eq Identification::IMPROVING
      expect( o.identifications.sort_by( &:id )[3].category ).to eq Identification::SUPPORTING
    end
  end
  describe "indexing" do
    it "should happen for other idents after new one added" do
      i1 = Identification.make!
      expect( i1.category ).to eq Identification::LEADING
      Identification.make!( observation: i1.observation, taxon: i1.taxon )
      i1.reload
      expect( i1.category ).to eq Identification::IMPROVING
      es_i1 = Identification.elastic_search( where: { id: i1.id } ).results.results[0]
      expect( es_i1.category ).to eq Identification::IMPROVING
    end

    it "should update this identification's category" do
      i1 = Identification.make!
      expect( i1.category ).to eq Identification::LEADING
      i2 = Identification.make!( observation: i1.observation, taxon: i1.taxon )
      i1.reload
      i2.reload
      expect( i1.category ).to eq Identification::IMPROVING
      expect( i2.category ).to eq Identification::SUPPORTING
      Delayed::Worker.new.work_off
      es_i2 = Identification.elastic_search( where: { id: i2.id } ).results.results[0]
      expect( es_i2.category ).to eq Identification::SUPPORTING
    end
  end
end

describe Identification, "disagreement" do
  elastic_models( Observation )
  before { load_test_taxa } # Not sure why but these don't seem to pass if I do before(:all)
  it "should be nil by default" do
    expect( Identification.make! ).not_to be_disagreement
  end
  it "should automatically set to true on create if the taxon is not a descendant or ancestor of the community taxon" do
    o = make_research_grade_observation( taxon: @Calypte_anna )
    2.times { Identification.make!( observation: o, taxon: o.taxon ) }
    i = Identification.make!( observation: o, taxon: @Pseudacris_regilla )
    i.reload
    expect( i ).to be_disagreement
  end
  it "should not be automatically set to true on update if the taxon is not a descendant or ancestor of the community taxon" do
    o = make_research_grade_candidate_observation
    i = Identification.make!( observation: o, taxon: @Calypte_anna )
    4.times { Identification.make!( observation: o, taxon: @Pseudacris_regilla ) }
    i.reload
    expect( i ).not_to be_disagreement
  end
  it "should not be automatically set to true if no other identifications are current" do
    o = Identification.make!( current: false ).observation
    Identification.make!( observation: o, taxon: @Calypte_anna )
    o.identifications.each {| i | i.update( current: false ) }
    i = Identification.make!( observation: o, taxon: @Pseudacris_regilla )
    expect( i ).not_to be_disagreement
  end

  describe "implicit disagreement" do
    it "should set disagreement to true" do
      o = Observation.make!( taxon: @Calypte_anna )
      Identification.make!( observation: o, taxon: @Calypte_anna )
      i = Identification.make!( observation: o, taxon: @Pseudacris_regilla )
      expect( i.disagreement ).to eq true
    end
    it "should not set disagreement previous obs taxon was ungrafted" do
      s1 = Taxon.make!( rank: Taxon::SPECIES )
      o = Observation.make!( taxon: s1 )
      Identification.make!( observation: o, taxon: s1 )
      i = Identification.make( observation: o, taxon: @Calypte_anna )
      i.save!
      expect( i.disagreement ).to be_nil
    end
    it "should not set disagreement if ident taxon is ungrafted" do
      s1 = Taxon.make!( rank: Taxon::SPECIES )
      o = Observation.make!( taxon: @Calypte_anna )
      Identification.make!( observation: o, taxon: @Calypte_anna )
      i = Identification.make!( observation: o, taxon: s1 )
      expect( i.disagreement ).to be_nil
    end
  end
end

describe Identification, "set_previous_observation_taxon" do
  elastic_models( Observation )
  it "should choose the observation taxon by default" do
    o = Observation.make!( taxon: Taxon.make!( :species ) )
    t = Taxon.make!( :species )
    3.times { Identification.make!( observation: o, taxon: t ) }
    o.reload
    previous_observation_taxon = o.taxon
    i = Identification.make!( observation: o )
    expect( i.previous_observation_taxon ).to eq previous_observation_taxon
  end

  it "should choose the probable taxon if the observer has opted out of the community taxon" do
    o = Observation.make!( taxon: Taxon.make!( :species ), prefers_community_taxon: false )
    t = Taxon.make!( :species )
    3.times { Identification.make!( observation: o, taxon: t ) }
    o.reload
    previous_observation_probable_taxon = o.probable_taxon
    i = Identification.make!( observation: o )
    expect( i.previous_observation_taxon ).to eq previous_observation_probable_taxon
  end

  it "should set it to the observer's previous identicication taxon if they are the only identifier" do
    genus = Taxon.make!( rank: Taxon::GENUS )
    species = Taxon.make!( rank: Taxon::SPECIES, parent: genus )
    o = Observation.make!( taxon: species )
    i1 = o.identifications.first
    o.reload
    expect( i1 ).to be_persisted
    i2 = Identification.make!( observation: o, taxon: genus, user: i1.user )
    expect( i2.previous_observation_taxon ).to eq i1.taxon
  end

  it "should not consider set a previous_observation_taxon to the identification taxon" do
    family = Taxon.make!( rank: Taxon::FAMILY )
    genus = Taxon.make!( rank: Taxon::GENUS, parent: family, name: "Homo" )
    species = Taxon.make!( :species, parent: genus, name: "Homo sapiens" )
    o = Observation.make!
    Identification.make!( observation: o, taxon: genus )
    i2 = Identification.make!( observation: o, taxon: species )
    o.reload
    expect( o.probable_taxon ).to eq species
    o.reload
    i3 = Identification.make!( observation: o, taxon: genus, user: i2.user, disagreement: true )
    expect( i3.previous_observation_taxon ).to eq species
  end

  it "should not happen when you restore a withdrawn ident" do
    genus = Taxon.make!( rank: Taxon::GENUS, name: "Genus" )
    species1 = Taxon.make!( rank: Taxon::SPECIES, parent: genus, name: "Genus speciesone" )
    species2 = Taxon.make!( rank: Taxon::SPECIES, parent: genus, name: "Genus speciestwo" )
    o = Observation.make!( taxon: species1 )
    i = Identification.make!( observation: o, taxon: genus, disagreement: true )
    expect( i.previous_observation_taxon ).to eq species1
    expect( o.taxon ).to eq genus
    i.update( current: false )
    o.reload
    expect( o.taxon ).to eq species1
    Identification.make!( observation: o, user: o.user, taxon: species2 )
    expect( o.taxon ).to eq species2
    i.update( current: true )
    expect( i.previous_observation_taxon ).to eq species1
  end
end

describe Identification, "update_disagreement_identifications_for_taxon" do
  elastic_models( Observation )
  let( :f ) { Taxon.make!( rank: Taxon::FAMILY ) }
  let( :g1 ) { Taxon.make!( rank: Taxon::GENUS, parent: f ) }
  let( :g2 ) { Taxon.make!( rank: Taxon::GENUS, parent: f ) }
  let( :s1 ) { Taxon.make!( rank: Taxon::SPECIES, parent: g1 ) }
  describe "should set disagreement to false" do
    it "when identification taxon becomes a descendant of the previous observation taxon" do
      t = Taxon.make!( rank: Taxon::SPECIES, parent: g2 )
      o = Observation.make!( taxon: g1 )
      i = Identification.make!( taxon: t, observation: o )
      expect( i.previous_observation_taxon ).to eq g1
      expect( i ).to be_disagreement
      without_delay { t.update( parent: g1 ) }
      i.reload
      expect( i ).not_to be_disagreement
    end
    it "when previous observation taxon becomes an ancestor of the identification taxon" do
      t = Taxon.make!( rank: Taxon::GENUS, parent: f )
      o = Observation.make!( taxon: t )
      i = Identification.make!( taxon: s1, observation: o )
      expect( i.previous_observation_taxon ).to eq t
      expect( i ).to be_disagreement
      without_delay { s1.update( parent: t ) }
      i.reload
      expect( i ).not_to be_disagreement
    end
  end
end
