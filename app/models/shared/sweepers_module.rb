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
  end
  
  def expire_listed_taxon(listed_taxon)
    expire_fragment(
      :controller => 'listed_taxa', 
      :action => 'show', 
      :id => listed_taxon.id)
  end
end