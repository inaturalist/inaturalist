class IndexFixes < ActiveRecord::Migration
  def self.up
    remove_index :observations, :column => [:created_at, :observed_on]
    remove_index :observations, :name => "index_observations_on_created_at_observed_on"
    add_index :observations, [:observed_on, :time_observed_at]
    add_index :observations, [:user_id, :observed_on, :time_observed_at], :name => "index_observations_user_datetime"
    add_index :comments, :user_id
    add_index :comments, [:parent_type, :parent_id]
    
    remove_index :taxa, :name => "index_taxa_on_rgt"
    remove_index :taxa, :name => "index_taxa_on_lft_and_rgt"
    
    add_index :listed_taxa, [:list_id, :taxon_ancestor_ids, :taxon_id]
  end

  def self.down
    add_index :observations, [:created_at, :observed_on]
    remove_index :observations, :column => [:observed_on, :time_observed_at]
    remove_index :observations, :name => "index_observations_user_datetime"
    remove_index :comments, :column => :user_id
    remove_index :comments, :column => [:parent_type, :parent_id]
    
    remove_index :listed_taxa, :column => [:list_id, :taxon_ancestor_ids, :taxon_id]
  end
end
