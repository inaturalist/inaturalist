class TaxonSplit < TaxonChange
  has_many :new_taxa, :through => :taxon_change_taxa, :source => :taxon
  validate :has_more_than_one_output

  def has_more_than_one_output
    unless taxon_change_taxa.size > 1
      errors.add( :base, "must have more than one output taxon" )
    end
  end
  
  def verb_phrase
    "split into"
  end

  def input_taxon
    taxon
  end

  def automatable?
    return true if output_taxa.detect{ |t| !t.atlased? }.nil?
    return true if output_ancestor
    false
  end

  def output_ancestor( options = { })
    if !@output_ancestor || options[:force]
      output_ancestor_id = output_taxa.first.ancestor_ids.reverse.detect do |aid|
        output_taxa.all? { |t| t.ancestor_ids.include?( aid ) }
      end
      if output_ancestor_id && ( Taxon::LIFE.blank? || output_ancestor_id != Taxon::LIFE.id )
        @output_ancestor = Taxon.find( output_ancestor_id )
      end
      @output_ancestor = nil if @output_ancestor && @output_ancestor.name == "Life"
    end
    @output_ancestor
  end

  def output_taxon_for_record( record )
    # note that record_place_ids includes *all* places that contain the record,
    # so for a point that would be any place with polygons containing the point,
    # and for places it means all ancestors of the place
    record_place_ids = if record.respond_to?( :place ) && record.place
      record.place.self_and_ancestor_ids
    elsif record.is_a?( Observation ) || record.respond_to?( :observation )
      o = record.is_a?( Observation ) ? record : record.observation
      o.observations_places.map(&:place_id)
    end
    if record_place_ids.blank?
      return output_ancestor
    end
    candidate_taxa = []
    output_taxa.each do |candidate_taxon|
      # don't even bother looking at more taxa if you already have ambiguity
      next if candidate_taxa.size > 1
      # a taxon without an atlas is a candidate since we don't know where it
      # exists
      unless candidate_taxon.atlased?
        candidate_taxa << candidate_taxon
        next
      end
      atlas_presence_place_containing_record = candidate_taxon.cached_atlas_presence_places.detect do |p|
        record_place_ids.include?( p.id )
      end
      if atlas_presence_place_containing_record
        candidate_taxa << candidate_taxon
      end
    end
    if candidate_taxa.size == 1
      # If there's only one left standing, that's the unambiguous output taxon
      candidate_taxa.first
    else
      # Otherwise, try the common ancestor of the outputs
      output_ancestor
    end
  end
end
