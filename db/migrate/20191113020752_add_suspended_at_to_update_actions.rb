class AddSuspendedAtToUpdateActions < ActiveRecord::Migration
  def up
    add_column :update_actions, :suspended_at, :timestamp

    # Consider all UpdateActions for places and taxa to be viewed since we're
    # about to start suspending subscriptions if they have a lot of unviewed
    # updates (and considering a place or taxon update to be "viewed" if the
    # subscriber views the obs)
    UpdateAction.__elasticsearch__.client.update_by_query(
      index: UpdateAction.index_name,
      body: {
        query: {
          bool: {
            must: [
              { terms: { resource_type: ["Place", "Taxon"] } }
            ]
          }
        },
        script: {
          source: "ctx._source.viewed_subscriber_ids = ctx._source.subscriber_ids"
        }
      }
    )
  end

  def down
    remove_column :update_actions, :suspended_at
  end
end
