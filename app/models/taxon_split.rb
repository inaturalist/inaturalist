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
    return @automatable unless @automatable.blank?
    if output_ancestor
      @automatable = true
    elsif output_taxa.detect{ |t| !t.atlased? }.nil?
      @automatable = true
    else
      @automatable = false
    end
    @automatable
  end

  def is_branching?
    output_taxa.map(&:id).include?( input_taxon.id )
  end

  def get_id_count_and_obs( params )
    params[:per_page] = 0
    id_count = INatAPIService.get( "/identifications", params ).total_results
    if id_count > 0
      params[:per_page] = ( id_count > 200 ? 200 : id_count )
      id_obs = INatAPIService.get( "/identifications", params ).results.map{ |r| r["observation"]["id"] }.uniq
    else
      id_obs = []
    end
    return { id_count: id_count, id_obs: id_obs }
  end

  def self.analyze_id_destinations( taxon_change )
    total_id_count = taxon_change.get_id_count_and_obs( { current: true, exact_taxon_id: taxon_change.input_taxon.id } )
    total_id_count[:taxon_id] = taxon_change.input_taxon.id
    total_id_count[:name] = taxon_change.input_taxon.name
    ancestor = taxon_change.output_ancestor
    output_id_counts = []
    if taxon_change.output_taxa.map{ |t| t.atlased? }.all?
      output_place_ids = []
      taxon_change.output_taxa.each do |output_taxon|
        output_place_ids << { output_taxon_id: output_taxon.id, places: output_taxon.atlas.presence_places }
      end

      presence_places_with_ancestries = output_place_ids.map{|row| row[:places].map{|a| a.self_and_ancestor_ids.reverse} }.flatten(1)
      presence_places = presence_places_with_ancestries.map{|row| row[0]}
      keepers = Place.where("id IN (?) AND admin_level IN (?)",presence_places_with_ancestries.flatten.uniq, [Place::COUNTRY_LEVEL, Place::STATE_LEVEL, Place::COUNTY_LEVEL]).pluck(:id)
      presence_places_plus_atlas_ancestors = presence_places_with_ancestries.map{|row| row & keepers }
      frequency_hash = presence_places_plus_atlas_ancestors.flatten.group_by(&:itself).transform_values!(&:size)
      unique_presence_places_plus_atlas_ancestors = presence_places_plus_atlas_ancestors.map{|a| a.join("_")}.uniq.map{|a| a.split("_").map{|a| a.to_i}}
      all_ancestors = unique_presence_places_plus_atlas_ancestors.map{|row| row[1..-1]}.flatten.uniq
      distinct_leaves = unique_presence_places_plus_atlas_ancestors.select{|row| !all_ancestors.include? row[0]}
      place_ids = []
      distinct_leaves.each do |distinct_leaf|
        place_ids << distinct_leaf[0] if distinct_leaf.map{|l| presence_places.select{|p| p==l}}.flatten.count > 1
      end
      if place_ids.empty?
        inside_multiple_count = { id_count: 0, id_obs: [] }
      else
        params = { current: true, place_id: place_ids, not_in_place: nil, exact_taxon_id: taxon_change.input_taxon.id }
        inside_multiple_count = taxon_change.get_id_count_and_obs(params)
      end
      inside_multiple_count[:taxon_id] = ancestor.id
      inside_multiple_count[:name] = ancestor.name

      taxon_change.output_taxa.each do |output_taxon|
        place_ids = output_place_ids.select{ |row| row[:output_taxon_id] ==  output_taxon.id }.first[:places].pluck( :id )
        if place_ids.empty?
          output_id_count = { id_count: 0, id_obs: [] }
        else
          not_in_place_ids = output_place_ids.select{ |row| row[:output_taxon_id] !=  output_taxon.id }.map{|row| row[:places].pluck( :id )}.flatten.uniq
          params = { current: true, place_id: place_ids, not_in_place: not_in_place_ids, exact_taxon_id: taxon_change.input_taxon.id }
          output_id_count = taxon_change.get_id_count_and_obs(params)
        end
        output_id_counts << { name: output_taxon.name, taxon_id: output_taxon.id, id_count: output_id_count[:id_count], id_obs: output_id_count[:id_obs], atlas_id: output_taxon.atlas.id, atlas_active: true }
      end

      all_presence_places = output_place_ids.map{|row| row[:places].pluck( :id ) }.flatten.uniq
      if all_presence_places.empty?
        outside_all_count = { id_count: 0, id_obs: [] }
      else
        params = { current: true, place_id: nil, not_in_place: all_presence_places, exact_taxon_id: taxon_change.input_taxon.id }
        outside_all_count = taxon_change.get_id_count_and_obs(params)
      end
      outside_all_count[:taxon_id] = ancestor.id
      outside_all_count[:name] = ancestor.name
    else
      taxon_change.output_taxa.each do |output_taxon|
        if atlas = output_taxon.atlas
          atlas_id = atlas.id
          atlas_active = atlas.is_active
        else
          atlas_id = nil
          atlas_active = nil
        end
        output_id_counts << { name: output_taxon.name, taxon_id: output_taxon.id, id_count: 0, id_obs: [], atlas_id: atlas_id, atlas_active: atlas_active }
      end
      outside_all_count = { name: ancestor.name, taxon_id: ancestor.id, id_count: total_id_count[:id_count], id_obs: total_id_count[:id_obs], atlas_id: nil }
      inside_multiple_count = { name: ancestor.name, taxon_id: ancestor.id, id_count: 0, id_obs: [], atlas_id: nil }
    end

    return {
      total_id_count: total_id_count,
      output_id_counts: output_id_counts,
      outside_all_count: outside_all_count,
      inside_multiple_count: inside_multiple_count
    }
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
      if o = record.is_a?( Observation ) ? record : record.observation
        o.observations_places.map(&:place_id)
      end
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
