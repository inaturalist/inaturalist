class ObservationSweeper < ActionController::Caching::Sweeper
  observe Observation
  include Shared::SweepersModule
  
  def after_create(observation)
    expire_taxon_caches_for_observation(observation)
    FileUtils.rm(private_page_cache_path(
      FakeView.observations_by_login_all_path(observation.user.login, :format => 'csv')
    ), :force => true)
    true
  end
  
  def after_update(observation)
    expire_taxon_caches_for_observation(observation)
    observation.listed_taxa.each {|lt| expire_listed_taxon(lt) }
    FileUtils.rm(private_page_cache_path(
      FakeView.observations_by_login_all_path(observation.user.login, :format => 'csv')
    ), :force => true)
    true
  end
  
  def after_destroy(observation)
    expire_taxon_caches_for_observation(observation)
    observation.listed_taxa.each {|lt| expire_listed_taxon(lt) }
    FileUtils.rm(private_page_cache_path(
      FakeView.observations_by_login_all_path(observation.user.login, :format => 'csv')
    ), :force => true)
    true
  end 

  def expire_taxon_caches_for_observation(observation)
    return unless (observation.taxon_id_changed? || observation.latitude_changed?)
    if observation.taxon_id_was && (taxon_was = Taxon.find_by_id(observation.taxon_id_was))
      expire_taxon_caches_for_taxon_later(taxon_was)
    end
    
    if observation.taxon_id && (taxon_is = Taxon.find_by_id(observation.taxon_id))
      expire_taxon_caches_for_taxon_later(taxon_is)
    end
  end

  def expire_taxon_caches_for_taxon_later(t)
    ObservationSweeper.
      delay(unique_hash: { "ObservationSweeper::expire_taxon_caches_for_taxon": t.id }).
      expire_taxon_caches_for_taxon(t.id)
  end

  def self.expire_taxon_caches_for_taxon(taxon_id)
    taxon = Taxon.find_by_id(taxon_id)
    return unless taxon
    ctrl = ActionController::Base.new
    I18N_SUPPORTED_LOCALES.each do |locale|
      ctrl.send :expire_action, FakeView.url_for(controller: 'observations', action: 'of', id: taxon.id, format: "json", locale: locale)
      ctrl.send :expire_action, FakeView.url_for(controller: 'observations', action: 'of', id: taxon.id, format: "geojson", locale: locale)
    end
  end
end
