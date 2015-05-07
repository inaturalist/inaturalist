class TaxonSweeper < ActionController::Caching::Sweeper
  observe Taxon
  include Shared::SweepersModule
  
  def after_update(taxon)
    expire_taxon(taxon)
  end
  
  def after_destroy(taxon)
    taxon = Taxon.find_by_id(taxon) unless taxon.is_a?(Taxon)
    return unless taxon
    expire_listed_taxa(taxon)
    ctrl = ActionController::Base.new
    ctrl.send(:expire_action, FakeView.url_for(:controller => 'taxa', :action => 'show', :id => taxon.id))
    ctrl.send(:expire_action, FakeView.url_for(:controller => 'taxa', :action => 'show', :id => taxon.to_param))
  end
end
