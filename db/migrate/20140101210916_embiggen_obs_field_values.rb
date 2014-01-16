class EmbiggenObsFieldValues < ActiveRecord::Migration
  def up
    change_column :observation_field_values, :value, :string, :limit => 2048
  end

  def down
    change_column :observation_field_values, :value, :string, :limit => 256
  end
end
