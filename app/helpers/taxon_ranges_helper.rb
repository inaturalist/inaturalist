module TaxonRangesHelper
  def iucn_relationship_text( taxon_range_iucn_relationship )
    case taxon_range_iucn_relationship
    when TaxonRange::IUCN_REDLIST_MAP
      t( :this_is_an_iucn_redlist_range_map )
    when TaxonRange::IUCN_REDLIST_MAP_HAS_ISSUES
      t( :iucn_redlist_range_map_for_this_taxon_has_issues )
    when TaxonRange::NOT_ON_IUCN_REDLIST
      t( :taxon_not_in_the_iucn_redlist )
    else
      t( :unknown )
    end
  end
end
