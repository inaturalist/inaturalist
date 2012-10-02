class CheckListsController < ApplicationController
  include Shared::ListsModule
  
  before_filter :authenticate_user!, :except => [:index, :show, :taxa]
  before_filter :load_list, :only => [:show, :edit, :update, :destroy, :compare, :remove_taxon, :add_taxon_batch, :taxa]
  before_filter :require_editor, :only => [:edit, :update, :destroy, :remove_taxon, :add_taxon_batch]
  before_filter :lock_down_default_check_lists, :only => [:edit, :update, :destroy]
  before_filter :load_find_options, :only => [:show]
  
  # Not supporting any of these just yet
  def index; redirect_to '/'; end
  
  def show
    @place = @list.place
    @other_check_lists = @place.check_lists.paginate(:page => 1)
    @other_check_lists.delete_if {|l| l.id == @list.id}
    
    # If this is a place's default check list, load ALL the listed taxa
    # belonging to this place.  Kind of weird, I know.  The alternative would
    # be to keep the default list updated with duplicates from all the other
    # check lists belonging to a place, like we do with parent lists.  It 
    # would be a pain to manage, but it might be faster.
    if @list.is_default?
      @find_options[:conditions] = update_conditions(
        @find_options[:conditions], ["AND place_id = ?", @list.place_id])
      
      # Make sure we don't get duplicate taxa from check lists other than the default
      @find_options[:select] = "DISTINCT (taxon_ancestor_ids || '/' || listed_taxa.taxon_id), listed_taxa.*"
      
      # Searches must use place_id instead of list_id for default checklists 
      # so we can search items in other checklists for this place
      if @q = params[:q]
        @search_taxon_ids = Taxon.search_for_ids(@q, :per_page => 1000)
        @find_options[:conditions] = update_conditions(
          @find_options[:conditions], ["AND listed_taxa.taxon_id IN (?)", @search_taxon_ids])
      end
      
      @listed_taxa = ListedTaxon.paginate(@find_options)
      
      @total_listed_taxa = ListedTaxon.count('DISTINCT(taxon_id)',
        :conditions => ["place_id = ?", @list.place_id])
    end
    super
  end
  
  def new
    unless @place = Place.find_by_id(params[:place_id])
      flash[:notice] = <<-EOT
        Check lists must belong to a place. To create a new check list, visit
        a place's default check list and click the 'Create a new check list'
        link.
      EOT
      return redirect_to places_path
    end
    
    @taxon = Taxon.find_by_id(params[:taxon_id].to_i)
    @iconic_taxa = Taxon.iconic_taxa
    @check_list = CheckList.new(:place => @place, :taxon => @taxon)
  end
  
  def create
    @check_list = CheckList.new(params[:check_list])
    @check_list.user = current_user
    
    # Override taxon choice with iconic taxon choice
    if params[:iconic_taxon] && (iconic_taxon = Taxon.find_by_id(params[:iconic_taxon][:id].to_i))
      @check_list.taxon = iconic_taxon
    end
    
    # add rules for all selected taxa
    if @check_list.taxon_id
      update_rules(@check_list, {:taxa => [{:taxon_id => @check_list.taxon_id}]})
    end
    
    respond_to do |format|
      if @check_list.save
        flash[:notice] = 'List was successfully created.'
        format.html { redirect_to(@check_list) }
      else
        @taxon = @check_list.taxon
        @iconic_taxa = Taxon.iconic_taxa
        format.html { render :action => "new" }
      end
    end
  end
  
  def edit
    @iconic_taxa = Taxon::ICONIC_TAXA || Taxon.iconic_taxa.all
  end
  
  def update
    if @list.update_attributes(params[:check_list])
      flash[:notice] = "Check list updated!"
      return redirect_to @list
    else
      @iconic_taxa = Taxon::ICONIC_TAXA || Taxon.iconic_taxa.all
      render :action => 'edit'
    end
  end
  
  private
  
  def load_list
    @list = CheckList.find_by_id(params[:id].to_i)
    render_404 && return unless @list
    true
  end
  
  def lock_down_default_check_lists
    if logged_in? && current_user.is_admin?
      flash[:notice] = "You can edit this default check list b/c you're an " + 
        "admin, but there shouldn't really be a need to do so."
      return true
    end
    if @list.is_default?
      flash[:error] = "You can't do that for the default check list of a place!"
      redirect_to @list
    end
  end
  
  def get_iconic_taxon_counts(list, iconic_taxa = nil)
    iconic_taxa ||= Taxon::ICONIC_TAXA
    iconic_taxon_counts_by_id_hash = if list.is_default?
      ListedTaxon.count('DISTINCT(taxon_id)', :group => "taxa.iconic_taxon_id",
        :joins => "JOIN taxa ON taxa.id = listed_taxa.taxon_id",
        :conditions => ["place_id = ?", list.place_id])
    else
      list.listed_taxa.count(:include => [:taxon], :group => "taxa.iconic_taxon_id")
    end
    iconic_taxa.map do |iconic_taxon|
      [iconic_taxon, iconic_taxon_counts_by_id_hash[iconic_taxon.id.to_s]]
    end
  end
end
