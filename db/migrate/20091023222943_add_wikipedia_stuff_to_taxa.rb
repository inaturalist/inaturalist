class AddWikipediaStuffToTaxa < ActiveRecord::Migration
  def self.up
    add_column :taxa, :wikipedia_summary, :text
    add_column :taxa, :wikipedia_title, :string
  end

  def self.down
    remove_column :taxa, :wikipedia_summary
    remove_column :taxa, :wikipedia_title
  end
end
