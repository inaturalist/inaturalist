class AddUniqueNameToTaxa < ActiveRecord::Migration
  def self.up
    add_column :taxa, :unique_name, :string
    add_index :taxa, :unique_name, :unique => true
    
    puts "Setting unique_name for all taxa.  This will take a while..."
    Taxon.find_each(:include => :taxon_names) do |taxon|
      taxon.update_unique_name(:force => true)
    end
  end

  def self.down
    remove_column :taxa, :unique_name
  end
end
