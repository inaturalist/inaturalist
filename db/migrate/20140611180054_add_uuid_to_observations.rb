# Add UUID column, as in https://tools.ietf.org/html/rfc4122. In theory this
# should be a unique index, but in practice we're mainly using it to prevent
# duplication from mobile clients with intermittent network connectivity
class AddUuidToObservations < ActiveRecord::Migration
  def change
    add_column :observations, :uuid, :string
    add_index :observations, :uuid
    add_column :observation_photos, :uuid, :string
    add_index :observation_photos, :uuid
  end
end
