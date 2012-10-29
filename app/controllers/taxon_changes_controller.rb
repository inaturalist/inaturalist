class TaxonChangesController < ApplicationController
  before_filter :curator_required, :except => [:index, :show]
  before_filter :admin_required, :only => [:commit_taxon_change]
  before_filter :load_taxon_change, :except => [:index, :new, :create]
  
  def index
    filter_params = params[:filters] || params
    @committed = filter_params[:committed]
    @types = filter_params[:types]
    @types ||= %w(split merge swap stage drop).map{|t| filter_params[t] == "1" ? t : nil}
    @types.delete_if{|t| t.blank?}
    @types = @types.map{|t| t =~ /^Taxon/ ? t : "Taxon#{t.capitalize}"}
    @iconic_taxon = Taxon.find_by_id(filter_params[:iconic_taxon_id]) unless filter_params[:iconic_taxon_id].blank?
    @source = Source.find_by_id(filter_params[:source_id]) unless filter_params[:source_id].blank?
    @taxon = Taxon.find_by_id(filter_params[:taxon_id].to_i) unless filter_params[:taxon_id].blank?
    @change_group = filter_params[:change_group] unless filter_params[:change_group].blank?
    @taxon_scheme = TaxonScheme.find_by_id(filter_params[:taxon_scheme_id]) unless filter_params[:taxon_scheme_id].blank?
    
    @change_groups = TaxonChange.all(:select => "change_group", :group => "change_group").map{|tc| tc.change_group}.compact.sort
    @taxon_schemes = TaxonScheme.all(:limit => 100).sort_by{|ts| ts.title}
    
    scope = TaxonChange.scoped
    if @committed == 'Yes'
      scope = scope.committed
    elsif @committed == 'No'
      scope = scope.uncommitted
    end
    scope = scope.types(@types) unless @types.blank?
    scope = scope.change_group(@change_group) if @change_group
    scope = scope.iconic_taxon(@iconic_taxon) if @iconic_taxon
    scope = scope.taxon(@taxon) if @taxon
    scope = scope.source(@source) if @source
    scope = scope.taxon_scheme(@taxon_scheme) if @taxon_scheme
    
    @taxon_changes = scope.paginate(
      :page => params[:page],
      :select => "DISTINCT (taxon_changes.id), taxon_changes.*",
      :include => [
        {:taxon => [:taxon_names, :photos, :taxon_ranges_without_geom, :taxon_schemes]},
        {:taxa => [:taxon_names, :photos, :taxon_ranges_without_geom, :taxon_schemes]},
        :source]
    )
    @taxa = @taxon_changes.map{|tc| [tc.taxa, tc.taxon]}.flatten
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
  
  def show
  end
  
  def new
    @change_groups = TaxonChange.all(:select => "change_group", :group => "change_group").map{|tc| tc.change_group}.compact.sort
    @klass = Object.const_get(params[:type]) rescue nil
    @klass = TaxonChange if @klass.blank? || @klass.superclass != TaxonChange
    @taxon_change = @klass.new
    @input_taxa = Taxon.where("id in (?)", params[:input_taxon_ids])
    @output_taxa = Taxon.where("id in (?)", params[:output_taxon_ids])
    @input_taxa.each {|t| @taxon_change.add_input_taxon(t)} unless @input_taxa.blank?
    @output_taxa.each {|t| @taxon_change.add_output_taxon(t)} unless @output_taxa.blank?
  end
  
  def create
    unless change_params = get_change_params
      flash[:error] = "No changes specified"
      redirect_back_or_default(taxon_changes_url)
      return
    end
    model = change_params.delete(:type).constantize
    @taxon_change = model.new(change_params)
    @taxon_change.user = current_user
    if @taxon_change.save
      flash[:notice] = 'Taxon Change was successfully created.'
      redirect_to :action => 'show', :id => @taxon_change
    else
      @change_groups = TaxonChange.all(:select => "change_group", :group => "change_group").map{|tc| tc.change_group}.compact.sort
      render :action => 'new'
    end
  end
  
  def edit
    @change_groups = TaxonChange.all(:select => "change_group", :group => "change_group").map{|tc| tc.change_group}.compact.sort
  end

  def update
    unless change_params = get_change_params
      flash[:error] = "No changes specified"
      redirect_back_or_default(@taxon_change)
      return
    end
    if @taxon_change.update_attributes(change_params)
      flash[:notice] = 'Taxon Change was successfully updated.'
      redirect_to taxon_change_path(@taxon_change)
      return
    else
      render :action => 'edit'
    end
  end
  
  def destroy
    if @taxon_change.destroy
      flash[:notice] = "Taxon change was deleted."
    else
      flash[:error] = "Something went wrong deleting the taxon change '#{@taxon_change.id}'!"
    end
    redirect_to :action => 'index'
  end
  
  def commit
    if @taxon_change.committed?
      flash[:error] = "This taxonomic change was already committed!"
      redirect_back_or_default(taxon_changes_path)
      return
    end
    
    @taxon_change.commit
    
    flash[:notice] = "Taxon change committed!"
    redirect_back_or_default(taxon_changes_path)
  end
  
  private
  def load_taxon_change
    render_404 unless @taxon_change = TaxonChange.find_by_id(params[:id] || params[:taxon_change_id], 
      :include => [
        {:taxon => [:taxon_names, :photos, :taxon_ranges_without_geom, :taxon_schemes]},
        {:taxa => [:taxon_names, :photos, :taxon_ranges_without_geom, :taxon_schemes]},
        :source]
    )
  end

  def get_change_params
    change_params = params[:taxon_change]
    TaxonChange::TYPES.each {|type| change_params ||= params[type.underscore]}
    change_params
  end
end
