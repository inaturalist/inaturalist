module Shared::SweepersModule
  def expire_listed_taxon(listed_taxon)
    return unless listed_taxon.list.is_a?(CheckList)
    listed_taxon.expire_caches
  end

  def expire_listed_taxa(taxon)
    return if taxon.blank?
    tid = taxon.id if taxon.is_a?(Taxon)
    ListedTaxon.delay(priority: USER_INTEGRITY_PRIORITY,
      unique_hash: { "ListedTaxon::expire_caches_for": tid }
    ).expire_caches_for(tid)
  end

  def expire_taxon(taxon)
    taxon = Taxon.find_by_id(taxon) unless taxon.is_a?(Taxon)
    return unless taxon
    expire_listed_taxa(taxon)
    ctrl = ActionController::Base.new
    ctrl.expire_fragment UrlHelper.url_for( controller: "taxa", action: "photos", id: taxon.id, partial: "photo" )
    I18N_SUPPORTED_LOCALES.each do | locale |
      [true, false].each do | ssl |
        ctrl.send( :expire_action, UrlHelper.url_for( controller: "taxa", action: "show", id: taxon.id, locale: locale,
          ssl: ssl ) )
        ctrl.send( :expire_action, UrlHelper.url_for( controller: "taxa", action: "show", id: taxon.to_param,
          locale: locale, ssl: ssl ) )
        ctrl.send( :expire_action, UrlHelper.taxon_path( id: taxon.id, locale: locale, format: "json" ) )
      end
    end
    Rails.cache.delete( taxon.photos_cache_key )
    Rails.cache.delete( taxon.photos_with_external_cache_key )
  end
end
