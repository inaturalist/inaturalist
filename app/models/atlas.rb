class Atlas < ActiveRecord::Base
  belongs_to :taxon
  has_many :exploded_atlas_places
  has_many :atlas_alterations
  
  def places
    exploded_place_ids_to_include, exploded_place_ids_to_exclude = get_exploded_place_ids_to_include_and_exclude
    Place.
      where( "(admin_level = 0 OR places.id IN (?))", exploded_place_ids_to_include ).
      where( "places.id NOT IN (?)", exploded_place_ids_to_exclude )
  end
  
  def presence_places
    exploded_place_ids_to_include, exploded_place_ids_to_exclude = get_exploded_place_ids_to_include_and_exclude
    Place.joins( listed_taxa: :list ).
      where( "lists.type = 'CheckList'").
      where( "lists.id = places.check_list_id" ).
      where( "listed_taxa.taxon_id = ?", taxon ).
      where( "(admin_level = 0 OR places.id IN (?))", exploded_place_ids_to_include ).
      where( "places.id NOT IN (?)", exploded_place_ids_to_exclude )
  end
  
  def get_exploded_place_ids_to_include_and_exclude
    exploded_place_ids_to_include = [0]
    exploded_place_ids_to_exclude = [0]
    exploded_atlas_places.each do |exploded_atlas_place|
      exploded_place_ids_to_exclude << exploded_atlas_place.place_id
      exploded_place_ids_to_include += exploded_atlas_place.place.children.where( "admin_level IN (0,1,2)" ).map(&:id)
    end
    return exploded_place_ids_to_include, exploded_place_ids_to_exclude
  end
end
