class EmbiggenPreferenceValues < ActiveRecord::Migration
  def up
    change_column :preferences, :value, :text
  end

  def down
    change_column :preferences, :value, :string, :limit => 256
  end
end
