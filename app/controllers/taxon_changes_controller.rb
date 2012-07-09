class TaxonChangesController < ApplicationController
  before_filter :curator_required
  
  def index
    if params[:iconic_taxon_id] && params[:source_id]
      @all = true
      iconic_taxon_id = params[:iconic_taxon_id] #20978
      source_id = params[:source_id] #27      
       
      @taxon_changes = TaxonChange.paginate(
       :page => params[:page],
       :include => [:taxon, {:taxon_change_taxa => :taxon}],
       :joins =>
         "LEFT OUTER JOIN taxon_change_taxa tct ON tct.taxon_change_id = taxon_changes.id " +
         "LEFT OUTER JOIN taxa t1 ON taxon_changes.taxon_id = t1.id " +
         "LEFT OUTER JOIN taxa t2 ON tct.taxon_id = t2.id",
       :conditions => [
         "(t1.iconic_taxon_id = ? AND t1.source_id = ?) OR (t2.iconic_taxon_id = ? AND t2.source_id = ?)",
         iconic_taxon_id, source_id, iconic_taxon_id, source_id]
      )
    elsif params[:taxon_id]
      @all = false
      @taxon = Taxon.find_by_id(params[:taxon_id])
      @taxon_changes = [
        TaxonChange.all(:conditions => {:taxon_id => params[:taxon_id]}),
        TaxonChangeTaxon.all(:conditions => {:taxon_id => params[:taxon_id]}).map{|tct| tct.taxon_change}].flatten
    else
      @all = true
      @taxon_changes = TaxonChange.paginate(
        :page => params[:page]
      )
    end
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
    unless TaxonChange.first(:conditions => {:id => params[:taxon_change_id], :committed_on => nil})
      flash[:error] = "This taxonomic change was already committed!"
      redirect_to :back and return
    end
    
    @taxon_change = TaxonChange.find_by_id(params[:taxon_change_id])
    TaxonChange.update_all(["committed_on = ?", Time.now],["id = ?", @taxon_change.id])
    
    if @taxon_change.class.name == 'TaxonSplit'
      Taxon.update_all({:is_active => false},["id = ?", @taxon_change.taxon_id])
      Taxon.update_all({:is_active => true},["id in (?)", @taxon_change.taxon_change_taxa.map{|tct| tct.taxon_id}])
    else
      Taxon.update_all({:is_active => false},["id in (?)", @taxon_change.taxon_change_taxa.map{|tct| tct.taxon_id}])
      Taxon.update_all({:is_active => true},["id = ?", @taxon_change.taxon_id])
    end
    
    flash[:notice] = "Taxon change committed!"
    redirect_to :back and return
  end
  
end