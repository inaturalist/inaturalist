class TaxonSchemesController < ApplicationController
  before_action :authenticate_user!, :except => [:index, :show]
  before_action :curator_required, :except => [:index, :show]
  before_action :load_taxon_scheme, :except => [:index]
  
  def index
    @taxon_schemes = TaxonScheme.paginate(:page => params[:page])  
  end

  def show
    @taxon_schemes = TaxonScheme.limit(100).sort_by{|ts| ts.title}
    @genus_only = false
    filter_params = params[:filters] || params
    @parent = Taxon.find_by_id(filter_params[:taxon_id].to_i) unless filter_params[:taxon_id].blank?
    parent_ids = @taxon_scheme.taxa.where("ancestry IS NOT NULL").
      select("DISTINCT ancestry").limit(1000).map do |t|
      t.ancestry.to_s.split('/')[-2..-1]
    end.flatten.uniq.compact
    @genera = []
    parent_ids.in_groups_of(100) do |ids|
      @genera += Taxon.of_rank('genus').where(id: ids.compact)
    end
    
    if @parent.blank? || @parent.rank != "genus"
      @taxa = @taxon_scheme.taxa.page(params[:page])
      @active_taxa = []
      @taxon_changes = []
      @orphaned_taxa = []
      @missing_taxa = []
      return
    end
    @active_taxa = @parent.children.joins(
      "JOIN taxon_scheme_taxa tst ON  tst.taxon_id = taxa.id " +
      "JOIN taxon_schemes ts ON ts.id = tst.taxon_scheme_id").
      where(is_active: true, rank: "species", ts: { id: @taxon_scheme })
    
    inat_taxa = @parent.children.where(rank: "species", is_active: true).order(:name)
    @missing_taxa = (inat_taxa - @active_taxa)
    
    inactive_taxa = @parent.children.joins(
      "JOIN taxon_scheme_taxa tst ON  tst.taxon_id = taxa.id " +
      "JOIN taxon_schemes ts ON ts.id = tst.taxon_scheme_id").
      where(is_active: false, rank: "species", ts: { id: @taxon_scheme })
    @taxon_changes = []
    @orphaned_taxa = []
    inactive_taxa.each do |taxon|
      scope = TaxonChange.all
      scope = scope.taxon(taxon)
      taxon_change = scope.select("DISTINCT ON (taxon_changes.id) taxon_changes.*").
        where(["type IN ('TaxonDrop') OR type IN ('TaxonStage') OR t1.is_active = ? OR t2.is_active = ?", true, true]).first
      if taxon_change
        @taxon_changes << taxon_change
        taxa_involved = [taxon_change.taxon,taxon_change.taxon_change_taxa.map{|tct| tct.taxon}].flatten
        @missing_taxa = @missing_taxa - taxa_involved
      else
        @orphaned_taxa << taxon #134111
      end
    end
    @taxon_changes = @taxon_changes.flatten.uniq
    
    @taxa = [@taxon_changes.map{|tc| [tc.taxa, tc.taxon]}, @orphaned_taxa,@missing_taxa,@active_taxa].flatten
    @swaps = TaxonSwap.joins([ { :taxon => :taxon_schemes }, { :taxa => :taxon_schemes } ]).
      where([ "taxon_changes.taxon_id IN (?) OR taxon_change_taxa.taxon_id IN (?)", @taxa, @taxa ])
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
    inactive_taxon_ids = @inactive_taxa.map(&:id)
    changes = TaxonChange.joins(:taxon_change_taxa).
      where(
        "taxon_changes.taxon_id IN (?) OR taxon_change_taxa.taxon_id IN (?)", 
        inactive_taxon_ids, inactive_taxon_ids
      )
    @taxon_changes = changes.to_a.select do |tc|
      @inactive_taxa.detect do |t|
        tc.taxon_id == t.id || tc.taxon_change_taxa.detect{|tct| tct.taxon_id == t.id}
      end
    end
  end
  
  def orphaned_inactive_taxa
    @inactive_taxa = Taxon.order('name').
         joins("JOIN taxon_scheme_taxa tst ON  tst.taxon_id = taxa.id").
         joins("JOIN taxon_schemes ts ON ts.id = tst.taxon_scheme_id").
         where("is_active = 'false' AND rank = 'species' AND ts.id = ?", @taxon_scheme).
         page(params[:page]).per_page(100)
    @orphaned_taxa = []
    @inactive_taxa.each do |taxon|
      scope = TaxonChange.all
      scope = scope.taxon(taxon)
      taxon_change = scope.select("DISTINCT (taxon_changes.id), taxon_changes.*").
        where(["type IN ('TaxonDrop') OR type IN ('TaxonStage') OR t1.is_active = ? OR t2.is_active = ?", true, true]).first
      unless taxon_change
        @orphaned_taxa << taxon
      end
    end
    return
  end
  
  private
  def load_taxon_scheme
    render_404 unless @taxon_scheme = TaxonScheme.includes(:source).find_by_id(params[:id])
  end
    
end
