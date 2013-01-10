class TaxonSchemesController < ApplicationController
  before_filter :load_taxon_scheme, :except => [:index]
  
  def index
    @taxon_schemes = TaxonScheme.paginate(:page => params[:page])  
  end

  def show
    @taxon_schemes = TaxonScheme.all(:limit => 100).sort_by{|ts| ts.title}
    @genus_only = false
    filter_params = params[:filters] || params
    @parent = Taxon.find_by_id(filter_params[:taxon_id].to_i) unless filter_params[:taxon_id].blank?
    parent_ids = @taxon_scheme.taxa.all(
        :limit => 1000, 
        :select => "DISTINCT ancestry", 
        :conditions => "ancestry IS NOT NULL").map do |t|
      t.ancestry.split('/')[-2..-1]
    end.flatten.uniq.compact
    @genera = []
    parent_ids.in_groups_of(100) do |ids|
      @genera += Taxon.of_rank('genus').all(:conditions => ["id IN (?)", ids.compact])
    end
    
    if @parent.blank? || @parent.rank != "genus"
      @taxa = @taxon_scheme.taxa.page(params[:page])
      @active_taxa = []
      @taxon_changes = []
      @orphaned_taxa = []
      @missing_taxa = []
      return
    end
    @active_taxa = @parent.children.all(
      :order => "name",
      :joins => 
        "JOIN taxon_scheme_taxa tst ON  tst.taxon_id = taxa.id " +
        "JOIN taxon_schemes ts ON ts.id = tst.taxon_scheme_id",
      :conditions => ["is_active = 'true' AND rank = 'species' AND ts.id = ?", @taxon_scheme]
    )
    
    inat_taxa = @parent.children.all(
      :order => "name",
      :conditions => ["rank = 'species' AND is_active = 'true'"]
    )
    @missing_taxa = (inat_taxa - @active_taxa)
    
    inactive_taxa = @parent.children.all(
      :order => "name",
      :joins => 
        "JOIN taxon_scheme_taxa tst ON  tst.taxon_id = taxa.id " +
        "JOIN taxon_schemes ts ON ts.id = tst.taxon_scheme_id",
      :conditions => ["is_active = 'false' AND rank = 'species' AND ts.id = ?", @taxon_scheme]
    )
    @taxon_changes = []
    @orphaned_taxa = []
    inactive_taxa.each do |taxon|
      scope = TaxonChange.scoped
      scope = scope.taxon(taxon)
      taxon_change = scope.first(
        :select => "DISTINCT (taxon_changes.id), taxon_changes.*",
        :conditions => ["type IN ('TaxonDrop') OR type IN ('TaxonStage') OR t1.is_active = ? OR t2.is_active = ?", true, true]
      )
      if taxon_change
        @taxon_changes << taxon_change
        taxa_involved = [taxon_change.taxon,taxon_change.taxon_change_taxa.map{|tct| tct.taxon}].flatten
        @missing_taxa = @missing_taxa - taxa_involved
      else
        @orphaned_taxa << taxon #134111
      end
    end
    @taxon_changes = @taxon_changes.flatten.uniq
    
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
  
  def mapped_inactive_taxa
    @inactive_taxa = Taxon.order('name').
         joins("JOIN taxon_scheme_taxa tst ON  tst.taxon_id = taxa.id").
         joins("JOIN taxon_schemes ts ON ts.id = tst.taxon_scheme_id").
         where("is_active = 'false' AND rank = 'species' AND ts.id = ?", @taxon_scheme).
         page(params[:page]).per_page(100)
    @taxon_changes = []
    @inactive_taxa.each do |taxon|
      scope = TaxonChange.scoped
      scope = scope.taxon(taxon)
      taxon_change = scope.first(
        :select => "DISTINCT (taxon_changes.id), taxon_changes.*",
        :conditions => ["type IN ('TaxonDrop') OR type IN ('TaxonStage') OR t1.is_active = ? OR t2.is_active = ?", true, true]
      )
      if taxon_change
        @taxon_changes << taxon_change
        taxa_involved = [taxon_change.taxon,taxon_change.taxon_change_taxa.map{|tct| tct.taxon}].flatten
      end
    end
    @taxon_changes = @taxon_changes.flatten.uniq
    return
  end
  
  def orphaned_inactive_taxa
    @inactive_taxa = Taxon.order('name').
         joins("JOIN taxon_scheme_taxa tst ON  tst.taxon_id = taxa.id").
         joins("JOIN taxon_schemes ts ON ts.id = tst.taxon_scheme_id").
         where("is_active = 'false' AND rank = 'species' AND ts.id = ?", @taxon_scheme).
         page(params[:page]).per_page(100)
    @orphaned_taxa = []
    @inactive_taxa.each do |taxon|
      scope = TaxonChange.scoped
      scope = scope.taxon(taxon)
      taxon_change = scope.first(
        :select => "DISTINCT (taxon_changes.id), taxon_changes.*",
        :conditions => ["type IN ('TaxonDrop') OR type IN ('TaxonStage') OR t1.is_active = ? OR t2.is_active = ?", true, true]
      )
      unless taxon_change
        @orphaned_taxa << taxon
      end
    end
    return
  end
  
  private
  def load_taxon_scheme
    render_404 unless @taxon_scheme = TaxonScheme.find_by_id(params[:id], 
      :include => [:source]
    )
  end
    
end
