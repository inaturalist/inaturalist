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

  def taxon_range_file_display_name( tr )
    if tr.range_file_size.is_a? Numeric
      filesize = "(#{ tr.range_file_size / 1000.to_f.round } KB)"
    else
      filesize = nil
    end
    if tr.range_file_name
      filename = tr.range_file_name
    else
      filename = t( :range_file )
    end
    if filesize
      display_name = [filename, filesize].join(" ")
    else
      display_name = filename
    end
    if tr.range.url
      return link_to display_name, tr.range.url
    else
      return display_name
    end
  end
end