class AddUpdatedAtToFlags < ActiveRecord::Migration
  def change
    add_column :flags, :updated_at, :timestamp
  end
end
