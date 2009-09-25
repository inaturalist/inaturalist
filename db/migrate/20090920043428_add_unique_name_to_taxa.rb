class AddUniqueNameToTaxa < ActiveRecord::Migration
  def self.up
    # add_column :taxa, :unique_name, :string
    # add_index :taxa, :unique_name, :unique => true
    
    puts "Setting unique_name for al taxa.  This will take a while..."
    ThinkingSphinx.deltas_enabled = false
    Taxon.find_each do |taxon|
      taxon.update_unique_name(:force => true)
    end
    ThinkingSphinx.deltas_enabled = true
  end

  def self.down
    remove_column :taxa, :unique_name
  end
end
