module Shared::SweepersModule
  
  # def self.included(base)
  #   base.extend ExpireHelpers
  # end
  # 
  # module ExpireHelpers
  #   def expire_observation_components(observation)
  #     controller.expire_fragment(
  #       :controller => 'observations', 
  #       :action => 'component', 
  #       :id => observation.id)
  #     controller.expire_fragment(
  #       :controller => 'observations', 
  #       :action => 'component', 
  #       :id => observation.id,
  #       :for_owner => true)
  # 
  #     # Expire page-cached tile_points JSON
  #     if observation.latitude? && observation.longitude?
  #       SPHERICAL_MERCATOR.levels.times do |zoom|
  #         x, y = SPHERICAL_MERCATOR.from_ll_to_pixel(
  #           [observation.longitude, observation.latitude], zoom)
  #         controller.expire_page :controller => 'observations', :action => 'tile_points', 
  #           :zoom => zoom, :x => x, :y => y
  #       end
  #     end
  #   end
  # 
  #   def expire_listed_taxon(listed_taxon)
  #     controller.expire_fragment(:controller => 'listed_taxa', :action => 'show', :id => listed_taxon.id)
  #     controller.expire_fragment(:controller => 'listed_taxa', :action => 'show', :id => listed_taxon.id, :for_owner => true)
  #     controller.expire_fragment(List.icon_preview_cache_key(listed_taxon.list_id))
  #     ListedTaxon::ORDERS.each do |order|
  #       controller.expire_fragment(:controller => 'observations', :action => 'add_from_list', :id => listed_taxon.list_id, :order => order)
  #     end
  #   end
  # 
  #   def expire_listed_taxa(taxon)
  #     ListedTaxon.find_each(:conditions => ["taxon_id = ?", taxon]) do |lt|
  #       expire_listed_taxon(lt)
  #     end
  #   end
  #   
  #   def controller
  #     is_a?(ApplicationController) ? self : ApplicationController.new
  #   end
  # end
  # 
  # private
  # include ExpireHelpers
  
  def expire_observation_components(observation)
    expire_fragment(observation.component_cache_key)
    expire_fragment(observation.component_cache_key(:for_owner => true))

    # Expire page-cached tile_points JSON
    if observation.latitude? && observation.longitude?
      SPHERICAL_MERCATOR.levels.times do |zoom|
        begin
          x, y = SPHERICAL_MERCATOR.from_ll_to_pixel([observation.longitude, observation.latitude], zoom)
          x = (x / 256).floor
          y = (y / 256).floor
          expire_page :controller => 'observations', :action => 'tile_points', 
            :zoom => zoom, :x => x, :y => y
        rescue Errno::EDOM => e
          # This is a rare and mysterious error.  Might have something to do 
          # with slicehost backups...
          Rails.logger.error "[ERROR #{Time.now}] Failed to sweep obs tilepoints while saving #{observation}: #{e}"
        end
      end
    end
  end

  def expire_listed_taxon(listed_taxon)
    expire_fragment(:controller => 'listed_taxa', :action => 'show', :id => listed_taxon.id)
    expire_fragment(:controller => 'listed_taxa', :action => 'show', :id => listed_taxon.id, :for_owner => true)
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
