# frozen_string_literal: true

require "spec_helper"

describe ActsAsElasticModel do
  elastic_models( Observation, Taxon, Identification, User )

  describe "callbacks" do
    it "properly indexes the document on create" do
      obs = Observation.make!
      result = Observation.elastic_search( where: { id: obs.id } )
      expect( result.count ).to eq 1
      expect( result.first.class ).to eq Elasticsearch::Model::Response::Result
      expect( result.first.id.to_i ).to eq obs.id
      expect( Time.parse( result.first.created_at ).round ).to eq obs.created_at.round
      expect( result.first.user.login ).to eq obs.user.login
    end

    it "properly deletes the document on destroy" do
      obs = Observation.make!
      expect( Observation.elastic_search( where: { id: obs.id } ).count ).to eq 1
      obs.destroy
      expect( Observation.elastic_search( where: { id: obs.id } ).count ).to eq 0
    end

    it "properly deletes the document on commit" do
      obs = Observation.make!
      expect( obs ).to receive( :elastic_delete! ).at_least( :twice )
      # we need to destroy to make sure we hit the after_commit on: destroy
      obs.destroy!
      # forcing the commit, which doesn't usually happen in specs
      obs.run_callbacks( :commit )
    end
  end

  describe "class methods" do
    describe "elastic_search" do
      it "searches for bool: { } as a wildcard query" do
        expect( Observation.__elasticsearch__ ).to receive( :search ).with(
          { query: { constant_score: { filter: { bool: {} } } } }
        ).and_return( true )
        Observation.elastic_search
      end

      it "adds matches to the query" do
        expect( Observation.__elasticsearch__ ).to receive( :search ).with(
          { query: { constant_score: { filter: { bool: {
            must: [{ match: { id: 5 } }]
          } } } } }
        ).and_return( true )
        Observation.elastic_search( where: { id: 5 } )
      end

      it "adds terms matches to the query" do
        expect( Observation.__elasticsearch__ ).to receive( :search ).with(
          { query: { constant_score: { filter: { bool: {
            must: [{ terms: { id: [1, 3] } }]
          } } } } }
        ).and_return( true )
        Observation.elastic_search( where: { id: [1, 3] } )
      end

      it "adds envelope filters" do
        expect( Observation.__elasticsearch__ ).to receive( :search ).with(
          { query: { constant_score: { filter: { bool: { must: [
            { geo_shape: { geojson: { shape: {
              type: "envelope", coordinates: [[-180, 88], [180, -90]]
            } } } }
          ] } } } } }
        ).and_return( true )
        Observation.elastic_search( filters: [{ envelope: { geojson: { nelat: 88 } } }] )
      end

      it "adds sorts to the query" do
        expect( Observation.__elasticsearch__ ).to receive( :search ).with(
          { query: { constant_score: { filter: { bool: {} } } },
            sort: { score: :desc } }
        ).and_return( true )
        Observation.elastic_search( sort: { score: :desc } )
      end

      it "allows certain fields to be specified" do
        expect( Observation.__elasticsearch__ ).to receive( :search ).with(
          { query: { constant_score: { filter: { bool: {} } } },
            _source: ["id", "description"] }
        ).and_return( true )
        Observation.elastic_search( source: ["id", "description"] )
      end

      it "adds aggregations to the query" do
        expect( Observation.__elasticsearch__ ).to receive( :search ).with(
          { query: { constant_score: { filter: { bool: {} } } },
            aggs: { colors: { terms: {
              field: :"colors.id", size: 10
            } } } }
        ).and_return( true )
        Observation.elastic_search( aggregate: { colors: { "colors.id": 10 } } )
      end
    end

    describe "elastic_paginate" do
      it "returns a WillPaginate collection" do
        expect( Observation.elastic_paginate ).to be_a WillPaginate::Collection
      end
      it "does not modify the options it receives" do
        options = { max_id: 1 }
        Observation.elastic_paginate( options )
        expect( options[:where] ).to be_nil
      end
    end

    describe "elastic_index!" do
      it "indexes instances of a class" do
        obs = Observation.make!
        expect( Observation.elastic_search( where: { id: obs.id } ).count ).to eq 1
        obs.elastic_delete!
        expect( Observation.elastic_search( where: { id: obs.id } ).count ).to eq 0
        Observation.elastic_index!
        expect( Observation.elastic_search( where: { id: obs.id } ).count ).to eq 1
      end

      it "accepts a scope" do
        obs1 = Observation.make!
        obs2 = Observation.make!
        obs1.elastic_delete!
        obs2.elastic_delete!
        expect( Observation.elastic_search.count ).to eq 0
        Observation.elastic_index!( scope: Observation.where( id: obs2 ) )
        expect( Observation.elastic_search.count ).to eq 1
        expect( Observation.elastic_search.first.id.to_i ).to eq obs2.id
      end

      it "accepts an array of ids" do
        obs1 = Observation.make!
        obs2 = Observation.make!
        obs1.elastic_delete!
        obs2.elastic_delete!
        expect( Observation.elastic_search.count ).to eq 0
        Observation.elastic_index!( ids: [obs2.id] )
        expect( Observation.elastic_search.count ).to eq 1
        expect( Observation.elastic_search.first.id.to_i ).to eq obs2.id
      end

      it "calls prepare_batch_for_index if it exists" do
        # Taxon uses prepare_batch_for_index, so it good for this test
        Taxon.make!
        expect( Taxon ).to receive( :prepare_batch_for_index )
        Taxon.elastic_index!
      end

      it "exceptions are caught silently" do
        expect( Observation.__elasticsearch__.client ).to receive( :bulk ).
          and_raise( Elastic::Transport::Transport::Errors::BadRequest )
        obs = Observation.make!
        obs.elastic_delete!
        Observation.elastic_index!
        expect( Observation.elastic_search.count ).to eq 0
      end

      it "sets last_index_at for Observations" do
        obs = Observation.make!
        obs.update_column( :last_indexed_at, 1.year.ago )
        expect( obs.last_indexed_at ).to be < 1.minute.ago
        Observation.elastic_index!
        obs.reload
        expect( obs.last_indexed_at ).to be > 1.minute.ago
      end

      it "can be delayed" do
        obs = Observation.make!
        obs.update_column( :last_indexed_at, 1.year.ago )
        expect( obs.last_indexed_at ).to be < 1.minute.ago
        Observation.elastic_index!( delay: true )
        expect( obs.last_indexed_at ).to be < 1.minute.ago
        Delayed::Worker.new.work_off
        obs.reload
        expect( obs.last_indexed_at ).to be > 1.minute.ago
      end

      it "can be delayed to run in the future" do
        Observation.make!
        run_job_at = 5.minutes.from_now
        Observation.elastic_index!( delay: true, run_at: run_job_at )
        delayed_job = Delayed::Job.last
        # there is a precision problem with CI where the times are not equal,
        # so instead ensure they match to some sub-second level of precision
        expect( ( delayed_job.run_at - run_job_at ).abs ).to be <= 0.0001
      end

      it "doesn't re-index obs indexed more than 5 minutes after delayed index request" do
        obs = Observation.make!
        Observation.elastic_index!( delay: true )
        less_than_five_minutes = 4.minutes.from_now
        obs.update_column( :last_indexed_at, less_than_five_minutes )
        Delayed::Worker.new.work_off
        obs.reload
        # obs indexed less than 5 minutes after delay request are re-indexed
        expect( obs.last_indexed_at ).to_not eq less_than_five_minutes

        Observation.elastic_index!( delay: true )
        more_than_five_minutes = 10.minutes.from_now
        obs.update_column( :last_indexed_at, more_than_five_minutes )
        Delayed::Worker.new.work_off
        obs.reload
        # obs index more than 5 minutes after delay request aren't re-indexed
        expect( ( obs.last_indexed_at - more_than_five_minutes ).abs ).to be < 1
      end
    end

    describe "elastic_delete_by_ids!" do
      it "deletes instances of a class from ES" do
        Observation.destroy_all
        obs = Observation.make!
        expect( Observation.count ).to eq 1
        expect( Observation.elastic_search( where: { id: obs.id } ).count ).to eq 1
        Observation.elastic_delete_by_ids!( [obs.id] )
        expect( Observation.elastic_search( where: { id: obs.id } ).count ).to eq 0
        expect( Observation.count ).to eq 1
      end
    end

    describe "result_to_will_paginate_collection" do
      it "returns an empty WillPaginate Collection on errors" do
        expect( WillPaginate::Collection ).to receive( :create ).
          and_raise( Elastic::Transport::Transport::Errors::BadRequest )
        expect( Taxon.result_to_will_paginate_collection(
          OpenStruct.new( current_page: 2, per_page: 11, total_entries: 57,
            results: OpenStruct.new( results: [] ) ) ) ).
          to eq WillPaginate::Collection.new( 1, 30, 0 )
      end
    end

    describe "elastic_get" do
      it "returns elasticsearch documents" do
        u = User.make!
        es_doc = User.elastic_get( u.id )
        expect( es_doc ).to be_a Elasticsearch::API::Response
        expect( es_doc["_source"]["id"] ).to eq u.id
        expect( es_doc["_source"]["login"] ).to eq u.login
      end

      it "returns nil for unknown IDs" do
        expect( User.elastic_get( 31_415 ) ).to be_nil
      end
    end

    describe "elastic_mget" do
      it "returns elasticsearch sources" do
        u1 = User.make!
        u2 = User.make!
        docs = User.elastic_mget( [u1.id, u2.id] )
        expect( docs ).to be_a Array
        expect( docs.find {| d | d["id"] == u1.id }["login"] ).to eq u1.login
        expect( docs.find {| d | d["id"] == u2.id }["login"] ).to eq u2.login
      end

      it "returns an empty array if none are found" do
        expect( User.elastic_mget( [] ) ).to eq []
        expect( User.elastic_mget( [31_415] ) ).to eq []
        expect( User.elastic_mget( [31_415, 31_416] ) ).to eq []
        expect( User.elastic_mget( [31_415, 31_416, "missing"] ) ).to eq []
      end
    end

    describe "elastic_sync" do
      it "indexes records" do
        User.make!( id: 10 )
        User.make!( id: 50_000 )
        User.make!( id: 50_001 )
        User.all.each( &:elastic_delete! )
        expect( User.elastic_search.count ).to eq 0
        expect( User ).to receive( :elastic_index! ).at_least( :once ).and_call_original
        User.elastic_sync
        expect( User.elastic_search.count ).to eq 3
      end

      it "indexes records even if they exist" do
        User.make!( id: 10 )
        User.make!( id: 50_000 )
        User.make!( id: 50_001 )
        expect( User.elastic_search.count ).to eq 3
        expect( User ).to receive( :elastic_index! ).at_least( :once ).and_call_original
        User.elastic_sync
        expect( User.elastic_search.count ).to eq 3
      end

      it "does not index existing records if requested" do
        User.make!( id: 10 )
        User.make!( id: 50_000 )
        User.make!( id: 50_001 )
        expect( User.elastic_search.count ).to eq 3
        expect( User ).not_to receive( :elastic_index! )
        User.elastic_sync( only_index_missing: true )
        expect( User.elastic_search.count ).to eq 3
      end

      it "does not index if requested" do
        User.make!( id: 10 )
        User.make!( id: 50_000 )
        User.make!( id: 50_001 )
        User.all.each( &:elastic_delete! )
        expect( User.elastic_search.count ).to eq 0
        expect( User ).not_to receive( :elastic_index! )
        User.elastic_sync( index_records: false )
        expect( User.elastic_search.count ).to eq 0
      end

      it "removes orphans" do
        User.make!( id: 10 )
        User.make!( id: 50_000 )
        User.make!( id: 50_001 )
        # deleting from the DB directly to bypass lifecycle callbacks
        # that would remove this record from ES on destroy
        User.connection.execute( "DELETE FROM users WHERE id=50000" )
        expect( User.count ).to eq 2
        expect( User.elastic_search.count ).to eq 3
        expect( User ).to receive( :elastic_delete_by_ids! ).and_call_original
        User.elastic_sync
        expect( User.count ).to eq 2
        expect( User.elastic_search.count ).to eq 2
      end

      it "does not remove orphans if requested" do
        User.make!( id: 10 )
        User.make!( id: 50_000 )
        User.make!( id: 50_001 )
        # deleting from the DB directly to bypass lifecycle callbacks
        # that would remove this record from ES on destroy
        User.connection.execute( "DELETE FROM users WHERE id=50000" )
        expect( User.count ).to eq 2
        expect( User.elastic_search.count ).to eq 3
        expect( User ).not_to receive( :elastic_delete_by_ids! )
        User.elastic_sync( remove_orphans: false )
        expect( User.count ).to eq 2
        expect( User.elastic_search.count ).to eq 3
      end
    end
  end

  describe "instance methods" do
    describe "elastic_index!" do
      it "indexes the instance" do
        taxon = Taxon.make!
        Taxon.all.each( &:elastic_delete! )
        expect( Taxon.elastic_search.count ).to eq 0
        taxon.elastic_index!
        expect( Taxon.elastic_search.count ).to eq 1
      end

      it "exceptions are caught silently" do
        taxon = Taxon.make!
        expect( taxon.__elasticsearch__ ).to receive( :index_document ).
          and_raise( Elastic::Transport::Transport::Errors::BadRequest )
        Taxon.all.each( &:elastic_delete! )
        expect( Taxon.elastic_search.count ).to eq 0
        taxon.elastic_index!
        expect( Taxon.elastic_search.count ).to eq 0
      end

      it "sets last_index_at for Observations" do
        obs = Observation.make!
        obs.update_column( :last_indexed_at, 1.year.ago )
        expect( obs.last_indexed_at ).to be < 1.minute.ago
        obs.elastic_index!
        obs.reload
        expect( obs.last_indexed_at ).to be > 1.minute.ago
      end

      it "does not wait for refresh by default" do
        obs = Observation.make!
        expect( obs.__elasticsearch__ ).to_not receive(
          :index_document
        ).with( { refresh: "wait_for" } )
        obs.elastic_index!
      end

      it "waits for refresh if requested" do
        obs = Observation.make!
        obs.wait_for_index_refresh = true
        expect( obs.__elasticsearch__ ).to receive(
          :index_document
        ).with( { refresh: "wait_for" } )
        obs.elastic_index!
      end
    end
  end
end
