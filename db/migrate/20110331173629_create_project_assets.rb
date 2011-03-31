class CreateProjectAssets < ActiveRecord::Migration
  def self.up
    create_table :project_assets do |t|
      t.integer :project_id
      t.timestamps
    end
    
    add_index :project_assets, :project_id
  end

  def self.down
    drop_table :project_assets
  end
end
