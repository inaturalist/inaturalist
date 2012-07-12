class TaxonChangesController < ApplicationController
  before_filter :curator_required
  
  def index
    
    options = {:page => params[:page]}
    conditions = ""
    merge_param = params[:merge] ? params[:merge] : false
    split_param = params[:split] ? params[:split] : false
    swap_param = params[:swap] ? params[:swap] : false
    stage_param = params[:stage] ? params[:stage] : false
    drop_param = params[:drop] ? params[:drop] : false
    conditions += "OR type = 'TaxonMerge'" if merge_param == 'true'
    conditions += "OR type = 'TaxonSplit'" if split_param == 'true'
    conditions += "OR type = 'TaxonDrop'" if drop_param == 'true'
    conditions += "OR type = 'TaxonStage'" if stage_param == 'true'
    conditions += "OR type = 'TaxonSwap'" if swap_param == 'true'
    conditions = conditions[3..-1] if conditions[0..2]=="OR "
    options[:conditions] = conditions
    
    if params[:iconic_taxon_id] && params[:source_id] #filter by iconic taxon and source
      @all = true
      iconic_taxon_id = params[:iconic_taxon_id] #20978
      source_id = params[:source_id] #27
      draft_only = params[:draft_only] ? params[:draft_only] : false
      if draft_only == 'true'
        @taxon_changes = TaxonChange.paginate(
          :page => params[:page],
          :select => "DISTINCT (taxon_changes.id), taxon_changes.*",
          :include => [:taxon, {:taxon_change_taxa => :taxon}],
          :joins =>
            "LEFT OUTER JOIN taxon_change_taxa tct ON tct.taxon_change_id = taxon_changes.id " +
            "LEFT OUTER JOIN taxa t1 ON taxon_changes.taxon_id = t1.id " +
            "LEFT OUTER JOIN taxa t2 ON tct.taxon_id = t2.id",
          :conditions => [
            "committed_on IS NULL AND" +
            "((t1.iconic_taxon_id = ? AND t1.source_id = ?) OR (t2.iconic_taxon_id = ? AND t2.source_id = ?))",
            iconic_taxon_id, source_id, iconic_taxon_id, source_id]
        )
      else
        @taxon_changes = TaxonChange.paginate(
          :page => params[:page],
          :select => "DISTINCT (taxon_changes.id), taxon_changes.*",
          :include => [:taxon, {:taxon_change_taxa => :taxon}],
          :joins =>
            "LEFT OUTER JOIN taxon_change_taxa tct ON tct.taxon_change_id = taxon_changes.id " +
            "LEFT OUTER JOIN taxa t1 ON taxon_changes.taxon_id = t1.id " +
            "LEFT OUTER JOIN taxa t2 ON tct.taxon_id = t2.id",
          :conditions => [
            "#{options} (t1.iconic_taxon_id = ? AND t1.source_id = ?) OR (t2.iconic_taxon_id = ? AND t2.source_id = ?)",
            iconic_taxon_id, source_id, iconic_taxon_id, source_id]
          )
      end
    elsif params[:taxon_id] #filter by taxon
      @all = false
      taxon_id = params[:taxon_id]
      @taxon = Taxon.find_by_id(taxon_id)
      #@taxon_changes = [
      #  TaxonChange.all(:conditions => {:taxon_id => params[:taxon_id]}),
      #  TaxonChangeTaxon.all(:conditions => {:taxon_id => params[:taxon_id]}).map{|tct| tct.taxon_change}].flatten
      
      @taxon_changes = TaxonChange.paginate(
        :page => params[:page],
        :select => "DISTINCT (taxon_changes.id), taxon_changes.*",
        :include => [:taxon, {:taxon_change_taxa => :taxon}],
        :joins =>
          "LEFT OUTER JOIN taxon_change_taxa tct ON tct.taxon_change_id = taxon_changes.id " +
          "LEFT OUTER JOIN taxa t1 ON taxon_changes.taxon_id = t1.id " +
          "LEFT OUTER JOIN taxa t2 ON tct.taxon_id = t2.id",
        :conditions => [
          "(t1.id = ?) OR (t2.id = ?)",
          taxon_id, taxon_id]
        )
    else #filter taxon_change type
      @all = true
      @taxon_changes = TaxonChange.paginate(options)
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