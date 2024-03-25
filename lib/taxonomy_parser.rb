# frozen_string_literal: true

class TaxonomyParser
  attr_reader :taxa

  def initialize
    fetch_all_taxa
    assign_nested_sets
  end

  def fetch_all_taxa
    @taxa = {}
    Taxon.active.select( :id, :ancestry ).find_each( batch_size: 10_000 ) do | taxon |
      @taxa[taxon.id] ||= {}
      @taxa[taxon.id][:id] = taxon.id
      @taxa[taxon.id][:ancestry] = taxon.ancestry
      @taxa[taxon.id][:children] = {}
      last_ancestor_id = 0
      @taxa[last_ancestor_id] ||= {}
      taxon.self_and_ancestor_ids.each do | ancestor_id |
        @taxa[ancestor_id] ||= {}
        @taxa[ancestor_id][:id] ||= ancestor_id
        if @taxa[ancestor_id][:parent_id] && @taxa[ancestor_id][:parent_id] != ancestor_id
          puts "[DEBUG] ancestry mismatch. Taxon #{ancestor_id} has existing parent " \
            "#{@taxa[ancestor_id][:parent_id]}, but parent #{ancestor_id} in ancestry of #{taxon.id}"
        end
        @taxa[ancestor_id][:parent_id] ||= ancestor_id
        @taxa[last_ancestor_id][:children] ||= {}
        @taxa[last_ancestor_id][:children][ancestor_id] = true
        last_ancestor_id = ancestor_id
      end
    end
  end

  def assign_nested_sets( taxon_id = 0, index = 0, depth = 0 )
    return unless @taxa[taxon_id]
    return if @taxa[taxon_id][:children].blank?

    descendant_count = 0
    leaf_count = 0
    @taxa[taxon_id][:children].each_key do | child_id |
      next unless @taxa[child_id]

      descendant_count += 1
      @taxa[child_id][:left] = index
      @taxa[child_id][:depth] = depth
      @taxa[child_id][:descendant_count] = 0
      @taxa[child_id][:leaf_count] = 0
      index += 1
      child_is_leaf = @taxa[child_id][:children].blank?
      if child_is_leaf
        leaf_count += 1
      else
        index, child_descendant_count, child_leaf_count = assign_nested_sets(
          child_id, index, depth + 1
        )
        descendant_count += child_descendant_count
        leaf_count += child_leaf_count
      end
      @taxa[child_id][:right] = index
      index += 1
    end
    @taxa[taxon_id][:descendant_count] = descendant_count
    @taxa[taxon_id][:leaf_count] = leaf_count
    [
      index,
      descendant_count,
      leaf_count
    ]
  end

  def inspect
    "#<TaxonomyParser @taxa=... >"
  end
end
