class TaxonChangesController < ApplicationController
  before_filter :curator_required
  
  def index
    filter_params = params[:filters] || params
    @committed = filter_params[:committed]
    @types = filter_params[:types] || []
    @types.delete_if{|t| t.blank?}
    @types = @types.map{|t| t =~ /^Taxon/ ? t : "Taxon#{t.capitalize}"}
    @iconic_taxon = Taxon.find_by_id(filter_params[:iconic_taxon_id]) unless filter_params[:iconic_taxon_id].blank?
    @source = Source.find_by_id(filter_params[:source_id]) unless filter_params[:source_id].blank?
    @taxon = Taxon.find_by_id(filter_params[:taxon_id]) unless filter_params[:taxon_id]
    @change_group = filter_params[:change_group] unless filter_params[:change_group].blank?
    @taxon_scheme = TaxonScheme.find_by_id(filter_params[:taxon_scheme_id])
    
    @change_groups = TaxonChange.all(:select => "change_group", :group => "change_group").map{|tc| tc.change_group}.sort
    @taxon_schemes = TaxonScheme.all(:limit => 100)
    
    scope = TaxonChange.scoped({})
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
      :page => filter_params[:page],
      :select => "DISTINCT (taxon_changes.id), taxon_changes.*",
      :include => [
        {:taxon => [:taxon_names, :photos, :taxon_ranges, :taxon_schemes]}, 
        {:taxon_change_taxa => {:taxon => [:taxon_names, :photos, :taxon_ranges, :taxon_schemes]}}, 
        :source]
    )
  end
  
  def show
    @taxon_change ||= TaxonChange.find_by_id(params[:id].to_i) if params[:id]
  end
  
  def new
    @taxon_change = TaxonChange.new
  end
  
  def create
    model = params[:taxon_change].delete(:type).constantize
    @taxon_change = model.new(params[:taxon_change])
    @taxon_change.user = current_user
    if @taxon_change.save
      flash[:notice] = 'Taxon Change was successfully created.'
      redirect_to :action => 'show', :id => @taxon_change
    else
      render :action => 'new'
    end
  end
  
  def edit
    @taxon_change = TaxonChange.find(params[:id])
  end

  def update
    @taxon_change = TaxonChange.find(params[:id])
    change_params = params[:taxon_change] ||= params[:taxon_split] ||= params[:taxon_merge]
    if @taxon_change.update_attributes(change_params)
      flash[:notice] = 'Taxon Change was successfully updated.'
      redirect_to taxon_change_path(@taxon_change)
      return
    else
      render :action => 'edit'
    end
  end
  
  def destroy
    @taxon_change = TaxonChange.find(params[:id])
    if @taxon_change.destroy
      flash[:notice] = "Taxon change was deleted."
    else
      flash[:error] = "Something went wrong deleting the taxon change '#{@taxon_change.id}'!"
    end
    redirect_to :action => 'index'
  end
  
  def commit_taxon_change
    unless logged_in?
      flash[:error] = "You don't have permission to commit this taxonomic change."
      redirect_to :back and return
    end
    taxon_change_id = params[:taxon_change_id]
    unless TaxonChange.first(:conditions => {:id => taxon_change_id, :committed_on => nil})
      flash[:error] = "This taxonomic change was already committed!"
      redirect_to :back and return
    end
    
    TaxonChange.send_later(:commit_taxon_change, taxon_change_id, :dj_priority => 2)
    
    flash[:notice] = "Taxon change committed!"
    redirect_to :back and return
  end
  
end