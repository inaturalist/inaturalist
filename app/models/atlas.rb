class Atlas < ActiveRecord::Base
  belongs_to :taxon
  belongs_to :user
  has_many :exploded_atlas_places, :inverse_of => :atlas, :dependent => :delete_all
  has_many :atlas_alterations, :inverse_of => :atlas, :dependent => :delete_all
  
  def places
    exploded_place_ids_to_include, exploded_place_ids_to_exclude = get_exploded_place_ids_to_include_and_exclude
    if exploded_place_ids_to_include.blank?
      places = Place.where( admin_level: 0 )
    else
      places = Place.where( "(admin_level = 0 OR places.id IN (?))", exploded_place_ids_to_include )
    end
    unless exploded_place_ids_to_exclude.blank?
      places = places.where( "places.id NOT IN (?)", exploded_place_ids_to_exclude )
    end
    places
  end
  
  def presence_places
    exploded_place_ids_to_include, exploded_place_ids_to_exclude = get_exploded_place_ids_to_include_and_exclude
    places = Place.joins( listed_taxa: :list ).
      where( "lists.type = 'CheckList'").
      where( "lists.id = places.check_list_id" ).
      where( "listed_taxa.taxon_id = ?", taxon )
    places = if exploded_place_ids_to_include.blank?
      places.where( admin_level: 0 )
    else
      places.where( "(admin_level = 0 OR places.id IN (?))", exploded_place_ids_to_include )
    end
    unless exploded_place_ids_to_exclude.blank?
      places = places.where( "places.id NOT IN (?)", exploded_place_ids_to_exclude )
    end
    places
  end
  
  def get_exploded_place_ids_to_include_and_exclude
    exploded_place_ids_to_include = []
    exploded_place_ids_to_exclude = []
    exploded_atlas_places.each do |exploded_atlas_place|
      exploded_place_ids_to_exclude << exploded_atlas_place.place_id
      exploded_place_ids_to_include += exploded_atlas_place.place.children.where( "admin_level IN (0,1,2)" ).map(&:id)
    end
    return exploded_place_ids_to_include, exploded_place_ids_to_exclude
  end
end
