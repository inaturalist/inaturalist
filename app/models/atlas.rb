class Atlas < ActiveRecord::Base
  has_subscribers
  belongs_to :taxon
  belongs_to :user
  has_many :exploded_atlas_places, inverse_of: :atlas, dependent: :delete_all
  has_many :atlas_alterations, inverse_of: :atlas, dependent: :delete_all
  has_many :comments, as: :parent, dependent: :destroy
  validates_uniqueness_of :taxon_id, :message => "already atlased"
  validates_presence_of :taxon

  def places
    exploded_place_ids_to_include, exploded_place_ids_to_exclude = get_exploded_place_ids_to_include_and_exclude
    if exploded_place_ids_to_include.blank?
      places = Place.where( admin_level: Place::COUNTRY_LEVEL )
    else
      places = Place.where( "( admin_level = ? OR places.id IN ( ? ) )", Place::COUNTRY_LEVEL, exploded_place_ids_to_include )
    end
    unless exploded_place_ids_to_exclude.blank?
      places = places.where( "places.id NOT IN ( ? )", exploded_place_ids_to_exclude )
    end
    places
  end

  def presence_places
    exploded_place_ids_to_include, exploded_place_ids_to_exclude = get_exploded_place_ids_to_include_and_exclude
    scope = ListedTaxon.joins( { list: :check_list_place } ).
      where( "lists.type = 'CheckList'" ).
      where( "listed_taxa.taxon_id IN ( ? )", taxon.taxon_ancestors_as_ancestor.pluck( :taxon_id ) )

    descendants_places = Place.where( id: scope.select( "listed_taxa.place_id" ).distinct.pluck( :place_id ) ).
      where( "admin_level IN (?)", [Place::COUNTRY_LEVEL, Place::STATE_LEVEL, Place::COUNTY_LEVEL] )
    place_ancestors = descendants_places.map{ |p| p.ancestor_place_ids.nil? ? [p.id] : p.ancestor_place_ids }.
      flatten.compact.uniq

    scope = Place.where( id: place_ancestors )
    if exploded_place_ids_to_include.blank?
      scope = scope.where( "places.admin_level = ?", Place::COUNTRY_LEVEL )
    else
      scope = scope.where( "( places.admin_level = ? OR places.id IN ( ? ) )", Place::COUNTRY_LEVEL, exploded_place_ids_to_include )
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
      exploded_place_ids_to_include += exploded_atlas_place.place.children.
        where( "admin_level IN (?)", [Place::COUNTRY_LEVEL, Place::STATE_LEVEL, Place::COUNTY_LEVEL] ).map( &:id )
    end
    return exploded_place_ids_to_include, exploded_place_ids_to_exclude
  end

  def get_atlas_presence_place_listed_taxa(place_id)
    place = Place.find(place_id)
    place_descendants = [place, Place.find(place_id).descendants.
      where('admin_level IN (?)',[Place::COUNTRY_LEVEL, Place::STATE_LEVEL, Place::COUNTY_LEVEL] ).pluck(:id ) ].
      compact.flatten
    ListedTaxon.joins( { list: :check_list_place } ).where( "lists.type = 'CheckList'" ).
    where( "listed_taxa.taxon_id IN (?)", taxon.taxon_ancestors_as_ancestor.pluck( :taxon_id ) ).
    where( "listed_taxa.place_id IN (?)", place_descendants )
  end

  def relevant_listed_taxon_alterations
    exploded_place_ids_to_include, exploded_place_ids_to_exclude = get_exploded_place_ids_to_include_and_exclude
    scope = ListedTaxonAlteration.joins( :place ).
      where( "taxon_id IN (?)", taxon.taxon_ancestors_as_ancestor.pluck( :taxon_id ) ).
      where( "places.admin_level IN (?)", [Place::COUNTRY_LEVEL, Place::STATE_LEVEL, Place::COUNTY_LEVEL] )
    unless exploded_place_ids_to_exclude.blank?
      scope = scope.where( "places.id NOT IN (?)", exploded_place_ids_to_exclude )
    end
    scope
  end
  
  def presence_places_with_establishment_means
    scope = ListedTaxon.joins( { list: :check_list_place } ).
      where( "lists.type = 'CheckList'" ).
      where( "listed_taxa.taxon_id IN ( ? )", taxon.taxon_ancestors_as_ancestor.pluck( :taxon_id ) )

    exploded_place_ids_to_include, exploded_place_ids_to_exclude = get_exploded_place_ids_to_include_and_exclude

    native_place_ids = scope.select( "listed_taxa.place_id" ).
      where( "listed_taxa.establishment_means IS NULL OR listed_taxa.establishment_means IN (?)", ListedTaxon::NATIVE_EQUIVALENTS ).
      distinct.pluck( :place_id ) 
    introduced_place_ids = scope.select( "listed_taxa.place_id" ).
      where( "listed_taxa.establishment_means IN (?)", ListedTaxon::INTRODUCED_EQUIVALENTS ).distinct.pluck( :place_id ) 

    descendants_places = Place.where( id: native_place_ids).
      where( "admin_level IN (?)", [Place::COUNTRY_LEVEL, Place::STATE_LEVEL, Place::COUNTY_LEVEL] )
    place_ancestors = descendants_places.map{ |p| p.ancestor_place_ids.nil? ? [p.id] : p.ancestor_place_ids }.
      flatten.compact.uniq
    scope = Place.where( id: place_ancestors )
    if exploded_place_ids_to_include.blank?
      scope = scope.where( "places.admin_level = ?", Place::COUNTRY_LEVEL )
    else
      scope = scope.where( "( places.admin_level = ? OR places.id IN ( ? ) )", Place::COUNTRY_LEVEL, exploded_place_ids_to_include )
    end
    unless exploded_place_ids_to_exclude.blank?
      scope = scope.where( "places.id NOT IN (?)", exploded_place_ids_to_exclude )
    end

    places = scope.map{|p| {id: p.id, establishment_means: "native"}}
    native_place_ids = places.map{|p| p[:id]}
    to_exclude = [exploded_place_ids_to_exclude, native_place_ids].flatten.uniq

    descendants_places = Place.where( id: introduced_place_ids).
      where( "admin_level IN (?)", [Place::COUNTRY_LEVEL, Place::STATE_LEVEL, Place::COUNTY_LEVEL] )
    place_ancestors = descendants_places.map{ |p| p.ancestor_place_ids.nil? ? [p.id] : p.ancestor_place_ids }.
      flatten.compact.uniq
    scope = Place.where( id: place_ancestors )
    if exploded_place_ids_to_include.blank?
      scope = scope.where( "places.admin_level = ?", Place::COUNTRY_LEVEL )
    else
      scope = scope.where( "( places.admin_level = ? OR places.id IN ( ? ) )", Place::COUNTRY_LEVEL, exploded_place_ids_to_include )
    end
    unless to_exclude.blank?
      scope = scope.where( "places.id NOT IN (?)", to_exclude )
    end

    places << scope.map{|p| {id: p.id, establishment_means: "introduced"}}
    places = places.flatten
  end
  
  def self.still_is_marked( atlas )
    return false if atlas.is_marked = false
    observation_search_url_params = { 
      verifiable: true, taxon_id: atlas.taxon_id, not_in_place: atlas.presence_places.pluck(:id).join( "," )
    }
    total_res = INatAPIService.observations( observation_search_url_params.merge( per_page: 0 ) ).total_results
    if total_res > 0
      return true
    end
    atlas.is_marked = false
    atlas.save
    return false
  end
  
  def self.mark_active_atlases_with_out_of_range_observations
    Atlas.where(is_active: true).each do |atlas|
     atlas_presence_places = atlas.presence_places
     observation_search_url_params = { 
       verifiable: true, taxon_id: atlas.taxon_id, not_in_place: atlas_presence_places.pluck(:id).join( "," )
     }
     total_res = INatAPIService.observations( observation_search_url_params.merge( per_page: 0 ) ).total_results
     if total_res == 0
       atlas.is_marked = false
     else
       atlas.is_marked = true
     end
     atlas.save
    end
  end
  
end
