# frozen_string_literal: true

class BackfillProjectObservationRequirementsUpdatedAt < ActiveRecord::Migration[6.1]
  def up
    scope = Project.
      where( project_type: ["collection", "umbrella"] ).
      where( observation_requirements_updated_at: nil )
    # capture the ids before update_all invalidates the scope's predicate
    project_ids = scope.pluck( :id )
    # A blank observation_requirements_updated_at blocks curator coordinate
    # access, and these projects predate the column, so their requirements
    # have never changed while any member trusted them. Treat the requirements
    # as unchanged since creation
    scope.in_batches( of: 10_000 ).update_all( "observation_requirements_updated_at = created_at" )
    Project.elastic_index!( ids: project_ids, delay: true )
  end

  def down
    # irreversible
  end
end
