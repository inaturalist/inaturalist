#encoding: utf-8
class GuideEolUpdateFlowTask < FlowTask

  def to_s
    "<GuideEolUpdateFlowTask #{id}>"
  end

  def run
    outputs.each(&:destroy)
    guide_taxa = inputs.select{|fti| fti.resource.is_a?(GuideTaxon) ? fti.resource : nil}.compact.map(&:resource).sort_by{|gt| gt.position || 0}
    return true if guide_taxa.blank?
    guide = guide_taxa.first.guide
    eol_collection = if guide.source_url && (collection_id = guide.source_url[/\/(\d+)(\.\w+)?$/, 1])
      eol.collections(collection_id, :per_page => guide.guide_taxa.count)
    end
    guide_taxa.each do |gt|
      gt.sync_eol(options.merge(:collection => eol_collection, :eol => eol))
    end
    true
  end

  def eol
    @eol ||= EolService.new(:timeout => 30, :debug => Rails.env.development?)
  end
end
