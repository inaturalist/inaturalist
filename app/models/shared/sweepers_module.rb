module Shared::SweepersModule
  def expire_observation_components(observation)
    expire_fragment(observation.component_cache_key)
    expire_fragment(observation.component_cache_key(:for_owner => true))
    I18N_SUPPORTED_LOCALES.each do |locale|
      expire_fragment(observation.component_cache_key, :locale => locale)
    end
  end

  def expire_listed_taxon(listed_taxon)
    expire_fragment(:controller => 'listed_taxa', :action => 'show', :id => listed_taxon.id)
    expire_fragment(:controller => 'listed_taxa', :action => 'show', :id => listed_taxon.id, :for_owner => true)
    expire_fragment(List.icon_preview_cache_key(listed_taxon.list_id))
    ListedTaxon::ORDERS.each do |order|
      expire_fragment(:controller => 'observations', :action => 'add_from_list', :id => listed_taxon.list_id, :order => order)
    end
    unless listed_taxon.place_id.blank?
      expire_fragment(listed_taxon.guide_taxon_cache_key)
      expire_page(:controller => 'places', :action => 'cached_guide', :id => listed_taxon.place_id)
      expire_page(:controller => 'places', :action => 'cached_guide', :id => listed_taxon.place.slug)
    end
    expire_page list_path(listed_taxon.list_id, :format => 'csv')
    expire_page list_show_formatted_view_path(listed_taxon.list_id, :format => 'csv', :view_type => 'taxonomic')
    if listed_taxon.list
      expire_page list_path(listed_taxon.list, :format => 'csv')
      expire_page list_show_formatted_view_path(listed_taxon.list, :format => 'csv', :view_type => 'taxonomic')
    end
    expire_action(:controller => 'taxa', :action => 'show', :id => listed_taxon.taxon_id)
  end

  def expire_listed_taxa(taxon)
    ListedTaxon.find_each(:conditions => ["taxon_id = ?", taxon]) do |lt|
      expire_listed_taxon(lt)
    end
  end

  def expire_taxon(taxon)
    taxon = Taxon.find_by_id(taxon) unless taxon.is_a?(Taxon)
    return unless taxon
    Observation.delay(:priority => USER_INTEGRITY_PRIORITY).expire_components_for(taxon.id)
    expire_listed_taxa(taxon)
    expire_fragment(:controller => 'taxa', :action => 'photos', :id => taxon.id, :partial => "photo")
    I18N_SUPPORTED_LOCALES.each do |locale|
      expire_action(:controller => 'taxa', :action => 'show', :id => taxon.id, :locale => locale)
      expire_action(:controller => 'taxa', :action => 'show', :id => taxon.to_param, :locale => locale)
    end
    Rails.cache.delete(taxon.photos_cache_key)
  end
end
