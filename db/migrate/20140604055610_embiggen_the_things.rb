class EmbiggenTheThings < ActiveRecord::Migration
  def up
    change_column :observation_fields, :allowed_values, :text
    change_column :users, :description, :text
  end

  def down
    change_column :observation_fields, :allowed_values, :string, :limit => 512
    change_column :users, :description, :string, :limit => 512
  end
end
