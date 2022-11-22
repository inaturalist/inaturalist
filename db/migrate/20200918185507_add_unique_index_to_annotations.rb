class AddUniqueIndexToAnnotations < ActiveRecord::Migration
  def up
    say "Deleting existing duplicate annotations..."
    obs_ids = Set.new
    Annotation.
        select( "resource_type, resource_id, controlled_attribute_id, controlled_value_id, min(id) AS id" ).
        where( resource_type: "Observation" ).
        group(
          :resource_type,
          :resource_id,
          :controlled_attribute_id,
          :controlled_value_id
        ).
        having( "count(*) > 1").
        each do |annotation|
      Annotation.
        where(
          resource_type: "Observation",
          resource_id: annotation.resource_id,
          controlled_attribute_id: annotation.controlled_attribute_id,
          controlled_value_id: annotation.controlled_value_id,
        ).
        where( "id != ?", annotation.id ).
        delete_all
      obs_ids << annotation.resource_id
    end
    execute <<-SQL
      CREATE UNIQUE INDEX index_annotations_on_unique_resource_and_attribute
      ON annotations(
        resource_type,
        resource_id,
        controlled_attribute_id,
        controlled_value_id
      )
    SQL
    say "Re-indexing #{obs_ids.size} observations..."
    Observation.elastic_index!( ids: obs_ids.to_a )
  end

  def down
    execute <<-SQL
      DROP INDEX index_annotations_on_unique_resource_and_attribute
    SQL
  end
end
