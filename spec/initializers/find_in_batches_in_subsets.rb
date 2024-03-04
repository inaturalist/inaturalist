# frozen_string_literal: true

require "spec_helper"

describe "ActiveRecord::Relation" do
  describe "find_in_batches_in_subsets" do
    it "raises an error on models without and integer id primary key" do
      expect do
        ObservationsPlace.where( "id > 0" ).find_in_batches_in_subsets {| _batch | next }
      end.to raise_error(
        "Models cannot use `find_in_batches_in_subsets` unless they have an integer `id` primary_key"
      )
    end

    it "loops through all results of the query" do
      obs1 = Observation.make!( id: 1 )
      obs2 = Observation.make!( id: 10_000_100 )
      ids_returned = []
      Observation.where( "id > 0" ).find_in_batches_in_subsets do | batch |
        ids_returned += batch.map( &:id )
      end
      expect( ids_returned ).to include( obs1.id )
      expect( ids_returned ).to include( obs2.id )
    end

    it "properly passes on query clauses" do
      obs1 = Observation.make!( id: 1 )
      obs2 = Observation.make!( id: 10_000_100 )
      ids_returned = []
      Observation.where( "id = ?", obs2.id ).find_in_batches_in_subsets do | batch |
        ids_returned += batch.map( &:id )
      end
      expect( ids_returned ).not_to include( obs1.id )
      expect( ids_returned ).to include( obs2.id )
    end

    it "properly passes on preloading includes" do
      Observation.make!( id: 1 )
      Observation.make!( id: 10_000_100 )
      ids_returned = []
      Observation.includes( :user ).where( "id > 0" ).find_in_batches_in_subsets do | batch |
        batch.each do | obs |
          ids_returned << obs.id
          expect( obs.association( :user ).loaded? ).to be true
        end
      end
      expect( ids_returned.length ).to eq 2

      ids_returned = []
      Observation.where( "id > 0" ).find_in_batches_in_subsets do | batch |
        batch.each do | obs |
          ids_returned << obs.id
          expect( obs.association( :user ).loaded? ).to be false
        end
      end
      expect( ids_returned.length ).to eq 2
    end

    it "makes multiple calls to find_in_batches" do
      Observation.make!( id: 1 )
      Observation.make!( id: 10_000_100 )
      call_count = 0
      allow_any_instance_of( ActiveRecord::Relation ).to receive( :find_in_batches ) do
        call_count += 1
      end
      Observation.where( "id > 0" ).find_in_batches_in_subsets {| _batch | next }
      expect( call_count ).to eq 51
    end
  end
end
