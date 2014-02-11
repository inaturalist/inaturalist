class CheckListsController < ApplicationController
  include Shared::ListsModule
  
  before_filter :authenticate_user!, :except => [:index, :show, :taxa]
  before_filter :load_list, :only => [:show, :edit, :update, :destroy, :compare, :remove_taxon, :add_taxon_batch, :taxa, :batch_edit]
  before_filter :require_editor, :only => [:edit, :update, :destroy, :remove_taxon]
  before_filter :require_listed_taxa_editor, :only => [:batch_edit, :add_taxon_batch]
  before_filter :lock_down_default_check_lists, :only => [:edit, :update, :destroy, :batch_edit]
  before_filter :set_find_options, :only => [:show]
  
  # Not supporting any of these just yet
  def index; redirect_to '/'; end
  
  def show
    @place = @list.place
    @other_check_lists = @place.check_lists.limit(1000)
    @other_check_lists.delete_if {|l| l.id == @list.id}
    
    # If this is a place's default check list, load ALL the listed taxa
    # belonging to this place.  Kind of weird, I know.  The alternative would
    # be to keep the default list updated with duplicates from all the other
    # check lists belonging to a place, like we do with parent lists.  It 
    # would be a pain to manage, but it might be faster.
    if @list.is_default?
      @unpaginated_listed_taxa = ListedTaxon.find_listed_taxa_from_default_list(@list.place_id)

      # Searches must use place_id instead of list_id for default checklists 
      # so we can search items in other checklists for this place
      if @q = params[:q]
        @search_taxon_ids = Taxon.search_for_ids(@q, :per_page => 1000)
        @unpaginated_listed_taxa = @unpaginated_listed_taxa.filter_by_taxa(@search_taxon_ids)
      end
      
    end
    super #show from list module
  end
  
  def new
    @place = Place.find(params[:place_id]) rescue nil
    unless @place
      flash[:notice] = t(:check_lists_must_belong_to_a_place)
      return redirect_to places_path
    end
    
    @taxon = Taxon.find_by_id(params[:taxon_id].to_i)
    @iconic_taxa = Taxon.iconic_taxa
    @check_list = CheckList.new(:place => @place, :taxon => @taxon)
  end
  
  def create
    @check_list = CheckList.new(params[:check_list])
    @check_list.user = current_user
    update_list_rules

    respond_to do |format|
      if @check_list.save
        flash[:notice] = t(:list_was_successfully_created)
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
    @check_list = @list
    update_list_rules
    if @list.update_attributes(params[:check_list])
      flash[:notice] = t(:check_list_updated)
      return redirect_to @list
    else
      @iconic_taxa = Taxon::ICONIC_TAXA || Taxon.iconic_taxa.all
      render :action => 'edit'
    end
  end
  
  private

  def update_list_rules
    # Override taxon choice with iconic taxon choice
    if params[:iconic_taxon] && (iconic_taxon = Taxon.find_by_id(params[:iconic_taxon][:id].to_i))
      @check_list.taxon = iconic_taxon
    end
    
    # add rules for all selected taxa
    if @check_list.taxon_id
      update_rules(@check_list, {:taxa => [{:taxon_id => @check_list.taxon_id}]})
    end
  end
  
  def load_list
    @list = CheckList.find_by_id(params[:id].to_i)
    render_404 && return unless @list
    true
  end
  
  def lock_down_default_check_lists
    if logged_in? && current_user.is_admin?
      flash[:notice] = t(:you_can_edit_this_default_check_list_because)
      return true
    end
    if @list.is_default?
      flash[:error] = t(:you_cant_do_that_for_the_default_check_list_place)
      redirect_to @list
    end
  end
  
  def get_iconic_taxon_counts(list, iconic_taxa = nil, listed_taxa = nil)
    iconic_taxa ||= Taxon::ICONIC_TAXA
    listed_taxa_iconic_taxon_ids = listed_taxa.map{|lt| lt.taxon.iconic_taxon_id }
    iconic_taxa.map do |iconic_taxon|
      taxon_count = listed_taxa_iconic_taxon_ids.count(iconic_taxon.id)
      [iconic_taxon, taxon_count]
    end
  end
end
