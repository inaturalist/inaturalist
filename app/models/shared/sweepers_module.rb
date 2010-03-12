module Shared::SweepersModule
  private
  def expire_observation_components(observation)
    expire_fragment(
      :controller => 'observations', 
      :action => 'component', 
      :id => observation.id)
    expire_fragment(
      :controller => 'observations', 
      :action => 'component', 
      :id => observation.id,
      :for_owner => true)
    
    # Expire page-cached tile_points JSON
    if observation.latitude? && observation.longitude?
      SPHERICAL_MERCATOR.levels.times do |zoom|
        x, y = SPHERICAL_MERCATOR.from_ll_to_pixel(
          [observation.longitude, observation.latitude], zoom)
        expire_page :controller => 'observations', :action => 'tile_points', 
          :zoom => zoom, :x => x, :y => y
      end
    end
  end
  
  def expire_listed_taxon(listed_taxon)
    expire_fragment(:controller => 'listed_taxa', :action => 'show', :id => listed_taxon)
    expire_fragment(:controller => 'listed_taxa', :action => 'show', :id => listed_taxon, :for_owner => true)
    expire_fragment(List.icon_preview_cache_key(listed_taxon.list_id))
    ListedTaxon::ORDERS.each do |order|
      expire_fragment(:controller => 'observations', :action => 'add_from_list', :id => listed_taxon.list_id, :order => order)
    end
  end
  
  def expire_listed_taxa(taxon)
    ListedTaxon.find_each(:conditions => ["taxon_id = ?", taxon]) do |lt|
      expire_listed_taxon(lt)
    end
  end
end