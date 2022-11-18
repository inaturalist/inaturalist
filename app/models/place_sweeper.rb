# frozen_string_literal: true

class PlaceSweeper < ActionController::Caching::Sweeper
  begin
    observe Place
  rescue ActiveRecord::NoDatabaseError
    puts "Database not connected, failed to observe Place. Ignore if setting up for the first time"
  end

  def after_update( place )
    remove_geometry_page_cache( place )
  end

  def after_destroy( place )
    remove_geometry_page_cache( place )
  end

  def after_merge( place )
    remove_geometry_page_cache( place )
  end

  private

  def remove_geometry_page_cache( place )
    ctrl = ActionController::Base.new
    ctrl.send :expire_page, UrlHelper.place_geometry_path( place, format: "kml" )
    ctrl.send :expire_page, UrlHelper.place_geometry_path( place.id, format: "kml" )
    ctrl.send :expire_page, UrlHelper.place_geometry_path( place, format: "geojson" )
    ctrl.send :expire_page, UrlHelper.place_geometry_path( place.id, format: "geojson" )
  end
end
