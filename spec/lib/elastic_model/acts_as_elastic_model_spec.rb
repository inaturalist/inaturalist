require "spec_helper"

describe ActsAsElasticModel do

  elastic_models( Observation, Taxon, Identification )

  describe "callbacks" do
    it "properly indexes the document on create" do
      obs = Observation.make!
      result = Observation.elastic_search( where: { id: obs.id } )
      expect( result.count ).to eq 1
      expect( result.first.class ).to eq Elasticsearch::Model::Response::Result
      expect( result.first.id.to_i ).to eq obs.id
      expect( Time.parse(result.first.created_at).round ).to eq obs.created_at.round
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
      expect(obs).to receive(:elastic_delete!).at_least(:twice)
      # we need to destroy to make sure we hit the after_commit on: destroy
      obs.destroy!
      # forcing the commit, which doesn't usually happen in specs
      obs.run_callbacks(:commit)
    end
  end

  describe "class methods" do
    describe "elastic_search" do
      it "searches for bool: { } as a wildcard query" do
        expect(Observation.__elasticsearch__).to receive(:search).with(
          { query: { constant_score: { filter: { bool: { } } } } }).and_return(true)
        Observation.elastic_search( )
      end

      it "adds matches to the query" do
        expect(Observation.__elasticsearch__).to receive(:search).with(
          { query: { constant_score: { filter: { bool: {
            must: [ { match: { id: 5 } } ] } } } } }).and_return(true)
        Observation.elastic_search(where: { id: 5 })
      end

      it "adds terms matches to the query" do
        expect(Observation.__elasticsearch__).to receive(:search).with(
          { query: { constant_score: { filter: { bool: {
            must: [ { terms: { id: [ 1, 3 ] } } ] } } } } }).and_return(true)
        Observation.elastic_search(where: { id: [ 1, 3] })
      end

      it "adds envelope filters" do
        expect(Observation.__elasticsearch__).to receive(:search).with(
          { query: { constant_score: { filter: { bool: { must: [
            { geo_shape: { geojson: { shape: {
              type: "envelope", coordinates: [[-180, 88], [180, -90]]}}}}]}}}}}).and_return(true)
        Observation.elastic_search(filters: [ { envelope: { geojson: { nelat: 88 }}}])
      end

      it "adds sorts to the query" do
        expect(Observation.__elasticsearch__).to receive(:search).with(
          { query: { constant_score: { filter: { bool: { } } } },
            sort: { score: :desc } }).and_return(true)
        Observation.elastic_search(sort: { score: :desc })
      end

      it "allows certain fields to be specified" do
        expect(Observation.__elasticsearch__).to receive(:search).with(
          { query: { constant_score: { filter: { bool: { } } } },
            _source: [ "id", "description" ] }).and_return(true)
        Observation.elastic_search(source: [ "id", "description" ])
      end

      it "adds aggregations to the query" do
        expect(Observation.__elasticsearch__).to receive(:search).with(
          { query: { constant_score: { filter: { bool: { } } } },
            aggs: { colors: { terms: {
              field: :"colors.id", size: 10 } } } }).and_return(true)
        Observation.elastic_search(aggregate: { colors: { "colors.id": 10 } } )
      end
    end

    describe "elastic_paginate" do
      it "returns a WillPaginate collection" do
        expect(Observation.elastic_paginate).to be_a WillPaginate::Collection
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
        expect( Observation.elastic_search( ).count ).to eq 0
        Observation.elastic_index!(scope: Observation.where(id: obs2))
        expect( Observation.elastic_search( ).count ).to eq 1
        expect( Observation.elastic_search( ).first.id.to_i ).to eq obs2.id
      end

      it "accepts an array of ids" do
        obs1 = Observation.make!
        obs2 = Observation.make!
        obs1.elastic_delete!
        obs2.elastic_delete!
        expect( Observation.elastic_search( ).count ).to eq 0
        Observation.elastic_index!(ids: [ obs2.id ])
        expect( Observation.elastic_search( ).count ).to eq 1
        expect( Observation.elastic_search( ).first.id.to_i ).to eq obs2.id
      end

      it "calls prepare_batch_for_index if it exists" do
        # Taxon uses prepare_batch_for_index, so it good for this test
        taxon = Taxon.make!
        expect(Taxon).to receive(:prepare_batch_for_index)
        Taxon.elastic_index!
      end

      it "exceptions are caught silently" do
        expect(Observation.__elasticsearch__.client).to receive(:bulk).
          and_raise(Elasticsearch::Transport::Transport::Errors::BadRequest)
        obs = Observation.make!
        obs.elastic_delete!
        Observation.elastic_index!
        expect( Observation.elastic_search( ).count ).to eq 0
      end

      it "sets last_index_at for Observations" do
        obs = Observation.make!
        obs.update_column(:last_indexed_at, 1.year.ago)
        expect( obs.last_indexed_at ).to be < 1.minute.ago
        Observation.elastic_index!
        obs.reload
        expect( obs.last_indexed_at ).to be > 1.minute.ago
      end

      it "can be delayed" do
        obs = Observation.make!
        obs.update_column(:last_indexed_at, 1.year.ago)
        expect( obs.last_indexed_at ).to be < 1.minute.ago
        Observation.elastic_index!( delay: true )
        expect( obs.last_indexed_at ).to be < 1.minute.ago
        Delayed::Worker.new.work_off
        obs.reload
        expect( obs.last_indexed_at ).to be > 1.minute.ago
      end

      it "doesn't re-index obs indexed more than 5 minutes after delayed index request" do
        obs = Observation.make!
        Observation.elastic_index!( delay: true )
        less_than_five_minutes = 4.minutes.from_now
        obs.update_column(:last_indexed_at, less_than_five_minutes)
        Delayed::Worker.new.work_off
        obs.reload
        # obs indexed less than 5 minutes after delay request are re-indexed
        expect( obs.last_indexed_at ).to_not eq less_than_five_minutes

        Observation.elastic_index!( delay: true )
        more_than_five_minutes = 10.minutes.from_now
        obs.update_column(:last_indexed_at, more_than_five_minutes)
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
        expect(WillPaginate::Collection).to receive(:create).
          and_raise(Elasticsearch::Transport::Transport::Errors::BadRequest)
        expect(Taxon.result_to_will_paginate_collection(
          OpenStruct.new(current_page: 2, per_page: 11, total_entries: 57,
            results: OpenStruct.new(results: [])))).
          to eq WillPaginate::Collection.new(1, 30, 0)
      end
    end
  end

  describe "instance methods" do
    describe "elastic_index!" do
      it "indexes the instance" do
        taxon = Taxon.make!
        Taxon.all.each{ |t| t.elastic_delete! }
        expect( Taxon.elastic_search( ).count ).to eq 0
        taxon.elastic_index!
        expect( Taxon.elastic_search( ).count ).to eq 1
      end

      it "exceptions are caught silently" do
        taxon = Taxon.make!
        expect(taxon.__elasticsearch__).to receive(:index_document).
          and_raise(Elasticsearch::Transport::Transport::Errors::BadRequest)
        Taxon.all.each{ |t| t.elastic_delete! }
        expect( Taxon.elastic_search( ).count ).to eq 0
        taxon.elastic_index!
        expect( Taxon.elastic_search( ).count ).to eq 0
      end

      it "sets last_index_at for Observations" do
        obs = Observation.make!
        obs.update_column(:last_indexed_at, 1.year.ago)
        expect( obs.last_indexed_at ).to be < 1.minute.ago
        obs.elastic_index!
        obs.reload
        expect( obs.last_indexed_at ).to be > 1.minute.ago
      end

      it "does not wait for refresh by default" do
        obs = Observation.make!
        expect( obs.__elasticsearch__ ).to_not receive(
          :index_document ).with( { refresh: "wait_for" } )
        obs.elastic_index!
      end

      it "waits for refresh if requested" do
        obs = Observation.make!
        obs.wait_for_index_refresh = true
        expect( obs.__elasticsearch__ ).to receive(
          :index_document ).with( { refresh: "wait_for" } )
        obs.elastic_index!
      end
    end

  end

end
