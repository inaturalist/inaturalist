class PlaceSweeper < ActionController::Caching::Sweeper
  observe Place
  
  def after_update(place)
    remove_geometry_page_cache(place)
  end
  
  def after_destroy(place)
    remove_geometry_page_cache(place)
  end
  
  def after_merge(place)
    remove_geometry_page_cache(place)
  end
  
  private
  def remove_geometry_page_cache(place)
    ctrl = ActionController::Base.new
    ctrl.send(:expire_page, FakeView.place_geometry_path(place, :format => "kml"))
    ctrl.send(:expire_page, FakeView.place_geometry_path(place.id, :format => "kml"))
    ctrl.send(:expire_page, FakeView.place_geometry_path(place, :format => "geojson"))
    ctrl.send(:expire_page, FakeView.place_geometry_path(place.id, :format => "geojson"))
  end
end
