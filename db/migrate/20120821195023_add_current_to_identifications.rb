class AddCurrentToIdentifications < ActiveRecord::Migration
  def change
    add_column :identifications, :current, :boolean, :default => true
  end
end
