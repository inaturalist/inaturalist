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
    scope = ListedTaxon.joins( { list: :check_list_place } ).
      where( "lists.type = 'CheckList'").
      where( "listed_taxa.taxon_id IN (?)", taxon.taxon_ancestors_as_ancestor.pluck(:taxon_id) )

    descendants_places = Place.where(id: scope.select("listed_taxa.place_id").distinct.pluck(:place_id)).where("admin_level IN (?)",[0,1,2])
    place_ancestors = descendants_places.map{|p| p.ancestor_place_ids.nil? ? [p.id] : p.ancestor_place_ids}.flatten.compact.uniq

    scope = Place.where(id: place_ancestors)
    if exploded_place_ids_to_include.blank?
      scope = scope.where( "places.admin_level = 0" )
    else
      scope = scope.where( "(places.admin_level = 0 OR places.id IN (?))", exploded_place_ids_to_include )
    end
    unless exploded_place_ids_to_exclude.blank?
      scope = scope.where( "places.id NOT IN (?)", exploded_place_ids_to_exclude )
    end
    scope
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
  
  def get_atlas_presence_place_listed_taxa(place_id)
    place = Place.find(place_id)
    place_descendants = [place, Place.find(place_id).descendants.where('admin_level IN (?)',[0,1,2]).pluck(:id)].compact.flatten
    ListedTaxon.joins( { list: :check_list_place } ).where( "lists.type = 'CheckList'").
    where( "listed_taxa.taxon_id IN (?)", taxon.taxon_ancestors_as_ancestor.pluck(:taxon_id) ).
    where("listed_taxa.place_id IN (?)", place_descendants)
  end
end
