module TaxonRangesHelper
  def iucn_relationship_text( taxon_range_iucn_relationship )
    case taxon_range_iucn_relationship
    when TaxonRange::IUCN_RED_LIST_MAP
      t( :taxon_range_iucn_relationship_this_is_an_iucn_red_list_range_map )
    when TaxonRange::IUCN_RED_LIST_MAP_UNSUITABLE
      t( :taxon_range_iucn_relationship_iucn_red_list_map_unsuitable )
    when TaxonRange::NOT_ON_IUCN_RED_LIST
      t( :taxon_range_iucn_relationship_taxon_not_on_the_iucn_red_list )
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

  def taxon_range_creator( taxon_range )
    if taxon_range.user_id == 0
      return "iNat"
    elsif taxon_range.user
      link_to( taxon_range.user.login, taxon_range.user )
    else
      return t( :deleted_user )
    end
  end

  def taxon_range_updater( taxon_range )
    if taxon_range.updater_id == 0
      return "iNat"
    elsif taxon_range.updater
      link_to( taxon_range.updater.login, taxon_range.updater )
    else
      return t( :deleted_user )
    end
  end
end