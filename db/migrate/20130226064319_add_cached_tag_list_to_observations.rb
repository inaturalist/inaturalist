class AddCachedTagListToObservations < ActiveRecord::Migration
  def change
    add_column :observations, :cached_tag_list, :string, :default => nil, :limit => 768
  end
end
