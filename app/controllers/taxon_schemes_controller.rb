class TaxonSchemesController < ApplicationController
  
  def index
    unless params[:parent_id] && params[:taxon_scheme_id]
      @taxa = []
      return
    end
    parent_id = params[:parent_id]
    taxon_scheme_id = params[:taxon_scheme_id]
    unless @parent = Taxon.find_by_id(parent_id)
      @taxa = []
      return
    end
    unless @taxon_scheme = TaxonScheme.find_by_id(taxon_scheme_id)
      @taxa = []
      return
    end
    @active_taxa = @parent.children.all(
      :joins => 
        "JOIN taxon_scheme_taxa tst ON  tst.taxon_id = taxa.id " +
        "JOIN taxon_schemes ts ON ts.id = tst.taxon_scheme_id",
      :conditions => ["is_active = 'true' AND rank = 'species' AND ts.id = ?", @taxon_scheme]
    )
    
    inat_taxa = @parent.children.all(
      :conditions => ["rank = 'species' AND is_active = 'true'"]
    )
    @missing_taxa = (inat_taxa - @active_taxa)
    
    inactive_taxa = @parent.children.all(
      :joins => 
        "JOIN taxon_scheme_taxa tst ON  tst.taxon_id = taxa.id " +
        "JOIN taxon_schemes ts ON ts.id = tst.taxon_scheme_id",
      :conditions => ["is_active = 'false' AND rank = 'species' AND ts.id = ?", @taxon_scheme]
    )
    @taxon_changes = []
    @orphaned_taxa = []
    inactive_taxa.each do |taxon|
      scope = TaxonChange.scoped({})
      scope = scope.taxon(taxon)
      taxon_change = scope.first(
        :select => "DISTINCT (taxon_changes.id), taxon_changes.*",
        :conditions => ["type IN ('TaxonDrop') OR t1.is_active = ? OR t2.is_active = ?", true, true]
      )
      if taxon_change
        @taxon_changes << taxon_change
        taxa_involved = [taxon_change.taxon,taxon_change.taxon_change_taxa.map{|tct| tct.taxon}].flatten
        @missing_taxa = @missing_taxa - taxa_involved
      else
        @orphaned_taxa << taxon #134111
      end
    end
    @taxon_changes = @taxon_changes.flatten
    
    @taxa = [@taxon_changes.map{|tc| [tc.taxa, tc.taxon]},@orphaned_taxa,@missing_taxa,@active_taxa].flatten
    @swaps = TaxonSwap.all(
      :include => [
        {:taxon => :taxon_schemes},
        {:taxa => :taxon_schemes}
      ], 
      :conditions => [
        "taxon_changes.taxon_id IN (?) OR taxon_change_taxa.taxon_id IN (?)",
        @taxa, @taxa
      ]
    )
    @swaps_by_taxon_id = {}
    @swaps.each do |swap|
      @swaps_by_taxon_id[swap.taxon_id] ||= []
      @swaps_by_taxon_id[swap.taxon_id] << swap
      swap.taxa.each do |taxon|
        @swaps_by_taxon_id[taxon.id] ||= []
        @swaps_by_taxon_id[taxon.id] << swap
      end
    end
  end
    
end