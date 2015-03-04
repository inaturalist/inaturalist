module Shared::SweepersModule
  def expire_listed_taxon(listed_taxon)
    listed_taxon.expire_caches
  end

  def expire_listed_taxa(taxon)
    return if taxon.blank?
    tid = taxon.id if taxon.is_a?(Taxon)
    ListedTaxon.delay(:priority => USER_INTEGRITY_PRIORITY).expire_caches_for(tid)
  end

  def expire_taxon(taxon)
    taxon = Taxon.find_by_id(taxon) unless taxon.is_a?(Taxon)
    return unless taxon
    expire_listed_taxa(taxon)
    ctrl = ActionController::Base.new
    ctrl.expire_fragment(FakeView.url_for(:controller => 'taxa', :action => 'photos', :id => taxon.id, :partial => "photo"))
    I18N_SUPPORTED_LOCALES.each do |locale|
      ctrl.send(:expire_action, FakeView.url_for(controller: 'taxa', action: 'show', id: taxon.id, locale: locale))
      ctrl.send(:expire_action, FakeView.url_for(controller: 'taxa', action: 'show', id: taxon.to_param, locale: locale))
    end
    Rails.cache.delete(taxon.photos_cache_key)
  end
end
