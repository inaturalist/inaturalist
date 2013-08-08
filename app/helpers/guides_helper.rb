#encoding: utf-8
module GuidesHelper
  def guide_taxa_from_params(gparams = nil)
    gparams ||= params || {}
    unless gparams[:taxon].blank?
      @taxon = Taxon::ICONIC_TAXA_BY_ID[gparams[:taxon]]
      @taxon ||= Taxon::ICONIC_TAXA_BY_NAME[gparams[:taxon]]
      @taxon ||= Taxon.find_by_name(gparams[:taxon]) || Taxon.find_by_id(gparams[:taxon])
      @taxon = nil if @taxon == @guide.taxon
    end
    @q = gparams[:q]
    @tags = gparams[:tags] || []
    @tags << gparams[:tag] unless gparams[:tag].blank?
    
    @guide_taxa = @guide.guide_taxa.order("guide_taxa.position").
      includes({:taxon => [:taxon_ranges_without_geom]}, {:guide_photos => :photo}, :guide_sections)
    @guide_taxa = @guide_taxa.in_taxon(@taxon) if @taxon
    @guide_taxa = @guide_taxa.dbsearch(@q) unless @q.blank?
    @guide_taxa = @guide_taxa.tagged(@tags) unless @tags.blank?
    @view = gparams[:view] || "grid"
    @guide_taxa
  end
end
