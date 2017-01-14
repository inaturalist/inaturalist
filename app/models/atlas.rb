class Atlas < ActiveRecord::Base
  has_subscribers
  belongs_to :taxon
  belongs_to :user
  has_many :exploded_atlas_places, inverse_of: :atlas, dependent: :delete_all
  has_many :atlas_alterations, inverse_of: :atlas, dependent: :delete_all
  has_many :comments, as: :parent, dependent: :destroy
  validates_uniqueness_of :taxon_id, :message => "already atlased"
  validates_presence_of :taxon

  # All of the atlased places, i.e. all the places where the atlas author has
  # declared this taxon to exist
  def places
    exploded_place_ids_to_include, exploded_place_ids_to_exclude = get_exploded_place_ids_to_include_and_exclude
    # If no places have been exploded, we assume the taxon exists in all countries
    if exploded_place_ids_to_include.blank?
      places = Place.where( admin_level: Place::COUNTRY_LEVEL )
    # Otherwise we assume it exists in all countries *and* all exploded places...
    else
      places = Place.where( "( admin_level = ? OR places.id IN ( ? ) )", Place::COUNTRY_LEVEL, exploded_place_ids_to_include )
    end
    # ...then we exclude places that we're explicitly ignoring
    unless exploded_place_ids_to_exclude.blank?
      places = places.where( "places.id NOT IN ( ? )", exploded_place_ids_to_exclude )
    end
    places
  end

  # All of the atlas places where there is a ListedTaxon demonstraging presence
  def presence_places
    exploded_place_ids_to_include, exploded_place_ids_to_exclude = get_exploded_place_ids_to_include_and_exclude
    descendant_listed_taxa = ListedTaxon.joins( list: :check_list_place ).
      where( "lists.type = 'CheckList'" ).
      where( "listed_taxa.taxon_id IN ( ? )", taxon.taxon_ancestors_as_ancestor.pluck( :taxon_id ) )
    descendant_place_ids = descendant_listed_taxa.select( "listed_taxa.place_id" ).distinct.pluck( :place_id )
    descendants_places = Place.where( id: descendant_place_ids ).
      where( "admin_level IN (?)", [Place::COUNTRY_LEVEL, Place::STATE_LEVEL, Place::COUNTY_LEVEL] )
    place_ancestor_ids = descendants_places.map{ |p| p.ancestor_place_ids || p.id }.
      flatten.compact.uniq

    places = Place.where( id: place_ancestor_ids )
    # If nothing is exploded, assume taxon is present in all countries with listed taxa for this taxon
    if exploded_place_ids_to_include.blank?
      places = places.where( "places.admin_level = ?", Place::COUNTRY_LEVEL )
    # Otherwise assume all countries AND explicitly included places
    else
      places = places.where( "( places.admin_level = ? OR places.id IN ( ? ) )", Place::COUNTRY_LEVEL, exploded_place_ids_to_include )
    end
    # Exclude places if necessary
    unless exploded_place_ids_to_exclude.blank?
      places = places.where( "places.id NOT IN (?)", exploded_place_ids_to_exclude )
    end
    places
  end

  def get_exploded_place_ids_to_include_and_exclude
    exploded_place_ids_to_include = []
    exploded_place_ids_to_exclude = []
    exploded_atlas_places.each do |exploded_atlas_place|
      # Exclude the exploded place itself
      exploded_place_ids_to_exclude << exploded_atlas_place.place_id
      # Include all admin level descendants of the exploded place
      exploded_place_ids_to_include += exploded_atlas_place.place.children.
        where( "admin_level IN (?)", [Place::COUNTRY_LEVEL, Place::STATE_LEVEL, Place::COUNTY_LEVEL] ).map( &:id )
    end
    [exploded_place_ids_to_include, exploded_place_ids_to_exclude]
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
    start_time = Time.now
    checked_count = 0
    failed_count = 0
    marked_count = 0
    unmarked_count = 0

    msg = "[INFO #{Time.now}] start daily check of #{ Atlas.where(is_active: true).count } active atlases"
    Rails.logger.info msg
    puts msg

    Atlas.where(is_active: true).each do |atlas|
      checked_count += 1
      change = false
      atlas_presence_places = atlas.presence_places
      observation_search_url_params = { 
        verifiable: true, taxon_id: atlas.taxon_id, not_in_place: atlas_presence_places.pluck(:id).join( "," )
      }
      total_res = INatAPIService.observations( observation_search_url_params.merge( per_page: 0 ) ).total_results
      if total_res == 0
        change = true if atlas.is_marked == true
      else
        change = true if atlas.is_marked == false
      end
      if change
        if atlas.is_marked
          atlas.is_marked = false
          msg = "[INFO #{Time.now}] atlas #{atlas.id} unmarked"
          unmarked_count += 1
        else
          atlas.is_marked = true
          msg = "[INFO #{Time.now}] atlas #{atlas.id} marked"
          marked_count += 1
        end
        Rails.logger.info msg
        puts msg    

        unless atlas.save
          failed_count += 1
          msg =  "[ERROR #{Time.now}] #{atlas.id} failed to save"
          Rails.logger.error msg
          puts msg
        end
      end
    end

    msg = "[INFO #{checked_count} atlases checked: #{marked_count} marked, #{unmarked_count} unmarked, #{failed_count} failed in #{Time.now - start_time} s"
    Rails.logger.info msg
    puts msg
  end

end
