class PlaceSweeper < ActionController::Caching::Sweeper  
  observe Place
  
  def after_update(place)
    remove_geometry_page_cache(place)
    expire_tiles(place) if place.latitude_changed? || place.longitude_changed?
  end
  
  def after_destroy(place)
    remove_geometry_page_cache(place)
    expire_tiles(place)
  end
  
  def after_merge(place)
    remove_geometry_page_cache(place)
    expire_tiles(place)
  end
  
  private
  def remove_geometry_page_cache(place)
    expire_page :controller => "places", :action => "geometry", :id => place.id
    expire_page :controller => "places", :action => "geometry", :id => place.id, :format => "kml"
  end
  
  def expire_tiles(place)    
    # Expire page-cached tile_points JSON
    Rails.logger.info "[INFO #{Time.now}] INAT_CONFIG['tile_servers']['tilestache_public_path']: #{INAT_CONFIG['tile_servers']['tilestache_public_path']}"
    return true unless stache_path = INAT_CONFIG['tile_servers']['tilestache_public_path']
    Rails.logger.info "[INFO #{Time.now}] place.latitude: #{place.latitude}, place.longitude: #{place.longitude}"
    return true unless place.latitude? && place.longitude?
    SPHERICAL_MERCATOR.levels.times do |zoom|
      x, y = SPHERICAL_MERCATOR.from_ll_to_world_coordinate([place.longitude, place.latitude], zoom)
      path = "#{stache_path}/place_points_*/#{zoom}/#{x}/#{y}*"
      Rails.logger.info "[INFO #{Time.now}] checking #{path}"
      targets = Dir.glob(path)
      next if targets.blank?
      puts "[INFO #{Time.now}] Deleting tile caches: #{targets.inspect}"
      FileUtils.rm targets
    end
  end
end