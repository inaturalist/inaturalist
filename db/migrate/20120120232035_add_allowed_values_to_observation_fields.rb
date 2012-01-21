class AddAllowedValuesToObservationFields < ActiveRecord::Migration
  def self.up
    add_column :observation_fields, :allowed_values, :string
  end

  def self.down
    remove_column :observation_fields, :allowed_values
  end
end
