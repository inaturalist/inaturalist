class AddTaxonToSubscription < ActiveRecord::Migration
  def self.up
    add_column :subscriptions, :taxon_id, :integer
    add_index :subscriptions, :taxon_id
  end

  def self.down
    remove_column :subscriptions, :taxon_id
  end
end
