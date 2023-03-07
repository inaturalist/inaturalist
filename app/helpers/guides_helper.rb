#encoding: utf-8
module GuidesHelper
  def guide_taxa_from_params(gparams = nil)
    gparams ||= if defined? params
      params || {}
    else
      {}
    end
    unless gparams[:taxon].blank?
      @taxon = Taxon::ICONIC_TAXA_BY_ID[gparams[:taxon]]
      @taxon ||= Taxon::ICONIC_TAXA_BY_NAME[gparams[:taxon]]
      @taxon ||= Taxon.find_by_name(gparams[:taxon]) || Taxon.find_by_id(gparams[:taxon])
      @taxon = nil if @taxon == @guide.taxon
    end
    @q = gparams[:q]
    @tags = ( gparams[:tags] || [] ).to_a.flatten
    @tags << gparams[:tag] unless gparams[:tag].blank?

    @sort = gparams[:sort]
    @sort = GuideTaxon::DEFAULT_SORT unless GuideTaxon::SORTS.include?(@sort)
    
    @guide_taxa = @guide.guide_taxa.
      includes({:taxon => [:taxon_range_without_geom]}, {:guide_photos => :photo}, :guide_sections, :guide_ranges, :tags)
    @guide_taxa = @guide_taxa.in_taxon(@taxon) if @taxon
    @guide_taxa = @guide_taxa.dbsearch(@q) unless @q.blank?
    @guide_taxa = @guide_taxa.tagged(@tags) unless @tags.blank?
    @guide_taxa = @guide_taxa.sorted_by(@sort)
    @view = gparams[:view] || "grid"
    @guide_taxa
  end

  def ngz_url( guide )
    return nil unless guide.downloadable?
    return nil if guide.ngz.url.blank?

    uri_join( root_url, guide.ngz.url ).to_s
  end
end
