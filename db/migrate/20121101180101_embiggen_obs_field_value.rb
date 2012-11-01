class EmbiggenObsFieldValue < ActiveRecord::Migration
  def up
    change_column :observation_fields, :allowed_values, :string, :limit => 512
  end

  def down
    change_column :observation_fields, :allowed_values, :string, :limit => 256
  end
end
