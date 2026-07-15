# frozen_string_literal: true

require "spec_helper"
require "rake"
require "timeout"

describe "gbif_observation_links tasks" do
  before( :all ) do
    Rake.application = Rake::Application.new
    Rake.application.rake_require( "tasks/gbif_observation_links", ["#{Rails.root}/lib"] )
    Rake::Task.define_task( :environment )
  end

  elastic_models( Observation )

  def make_gbif_link( observation )
    ObservationLink.create!(
      observation: observation,
      href: "http://www.gbif.org/occurrence/#{observation.id}",
      href_name: "GBIF",
      rel: "alternate"
    )
  end

  describe "gbif_es_drifted_observation_ids" do
    it "reports observations whose GBIF links are missing from their ES doc" do
      drifted = Observation.make!
      # the link is created after the observation was indexed, and creating a
      # link does not reindex the observation, so the ES doc has no outlink
      make_gbif_link( drifted )
      reported_ids = []
      gbif_es_drifted_observation_ids {| drifted_ids, _drifted_count | reported_ids.concat( drifted_ids ) }
      expect( reported_ids ).to include drifted.id
    end

    it "does not report observations whose ES doc includes their GBIF link" do
      indexed = Observation.make!
      make_gbif_link( indexed )
      Observation.elastic_index!( ids: [indexed.id] )
      expect( gbif_es_drifted_observation_ids ).not_to include indexed.id
    end

    it "does not report observations that only have non-GBIF links" do
      observation = Observation.make!
      ObservationLink.create!(
        observation: observation,
        href: "http://biocache.ala.org.au/occurrences/abc-123",
        href_name: "Atlas of Living Australia",
        rel: "alternate"
      )
      expect( gbif_es_drifted_observation_ids ).not_to include observation.id
    end
  end

  describe "gbif_observation_links:backfill_es_drift" do
    let( :task ) { Rake::Task["gbif_observation_links:backfill_es_drift"] }

    before do
      task.reenable
    end

    it "queues delayed reindexing for drifted observations" do
      drifted = Observation.make!
      make_gbif_link( drifted )
      allow( Observation ).to receive( :elastic_index! )
      task.invoke
      expect( Observation ).to have_received( :elastic_index! ).with(
        hash_including( delay: true, ids: [drifted.id] )
      )
    end

    it "queues a separate indexing job per index_batch_size drifted observations" do
      drifted = Array.new( 2 ) { Observation.make! }
      drifted.each {| observation | make_gbif_link( observation ) }
      allow( Observation ).to receive( :elastic_index! )
      task.invoke( "1" )
      drifted.each do | observation |
        expect( Observation ).to have_received( :elastic_index! ).with(
          hash_including( delay: true, ids: [observation.id] )
        )
      end
    end

    it "falls back to the default batch size instead of looping forever when given a non-positive size" do
      drifted = Observation.make!
      make_gbif_link( drifted )
      allow( Observation ).to receive( :elastic_index! )
      # A non-positive size used to spin the queue-draining loop forever; the
      # Timeout guards against a regression hanging the suite.
      Timeout.timeout( 30 ) { task.invoke( "0" ) }
      expect( Observation ).to have_received( :elastic_index! ).with(
        hash_including( delay: true, ids: [drifted.id] )
      )
    end
  end
end
