class EmbiggenObsFieldAllowedValues < ActiveRecord::Migration
  def up
    change_column :observation_fields, :allowed_values, :text
  end

  def down
    change_column :observation_fields, :allowed_values, :string, :limit => 512
  end
end
