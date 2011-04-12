class AddSpeciesCountToLists < ActiveRecord::Migration
  def self.up
    add_column :lists, :species_count, :integer, :default => 0
    List.all.each do |the_list|
      the_list.species_count = the_list.listed_taxa.count(
        'DISTINCT(taxon.id)',
        :include =>:taxon,
        :conditions => [
          "taxa.rank_level <= ?",
          Taxon::RANK_LEVELS['species']
        ]
      )
      the_list.save
    end
  end
  
  def self.down
    remove_column :lists, :species_count
  end
end
