class AddReferenceObservationIdToIdSummaryReferences < ActiveRecord::Migration[6.1]
  def change
    add_column :id_summary_references, :reference_observation_id, :integer
  end
end
