class CheckListsController < ApplicationController
  include Shared::ListsModule
  
  before_filter :authenticate_user!, :except => [:index, :show, :taxa]
  before_filter :load_list, :only => [:show, :edit, :update, :destroy, :compare, :remove_taxon, :add_taxon_batch, :taxa, :batch_edit]
  before_filter :require_editor, :only => [:edit, :update, :destroy, :remove_taxon]
  before_filter :require_listed_taxa_editor, :only => [:batch_edit, :add_taxon_batch]
  before_filter :lock_down_default_check_lists, :only => [:edit, :update, :destroy, :batch_edit]
  before_filter :set_iconic_taxa, :only => [:show]

  # Not supporting any of these just yet
  def index; redirect_to '/'; end
  
  def show
    @place = @list.place
    @other_check_lists = @place.check_lists.where("id != ?", @list.id).limit(1000)

    # If this is a place's default check list, load ALL the listed taxa
    # belonging to this place.  Kind of weird, I know.  The alternative would
    # be to keep the default list updated with duplicates from all the other
    # check lists belonging to a place, like we do with parent lists.  It 
    # would be a pain to manage, but it might be faster.
    if @list.is_default?
      @unpaginated_listed_taxa = ListedTaxon.find_listed_taxa_from_default_list(@list.place_id)

      # Searches must use place_id instead of list_id for default checklists 
      # so we can search items in other checklists for this place
      if (@q = params[:q]) && !@q.blank?
        @search_taxon_ids = Taxon.elastic_search(
          filters: [ { match: { "names.name": { query: @q, operator: "and" } } } ]).per_page(1000).map(&:id)
        @unpaginated_listed_taxa = @unpaginated_listed_taxa.filter_by_taxa(@search_taxon_ids)
      end
    end

    if params[:find_missing_listings]
      @missing_filter_taxon = params[:missing_filter_taxon].present? ? Taxon.find(params[:missing_filter_taxon]) : nil
      @hide_descendants = params[:hide_descendants]
      @hide_ancestors = params[:hide_ancestors]
      @missing_listings_list = params[:missing_listing_list_id].present? ? List.find_by_id(params[:missing_listing_list_id]) : nil
      list_ids_from_projects = ProjectList.joins(:project).where("projects.place_id = ?", @list.place_id).pluck(:id)
      @lists_for_missing_listings = List.where("(place_id = ? AND id != ?) OR id IN (?)", @list.place_id, @list.id, list_ids_from_projects).order(:title)
      missing_listings_list_ids = @lists_for_missing_listings.map(&:id)
      listed_taxa_on_this_list = @list.find_listed_taxa_and_ancestry_as_hashes
      listed_taxa_on_other_lists = @list.find_listed_taxa_and_ancestry_on_other_lists_as_hashes(missing_listings_list_ids)
      scoped_list = apply_missing_listings_scopes(listed_taxa_on_this_list, listed_taxa_on_other_lists, @missing_filter_taxon, @hide_ancestors, @hide_descendants, @missing_listings_list)
      ids_for_listed_taxa_on_other_lists = scoped_list.map{|lt| lt['id'] }
      @missing_listings = ListedTaxon.where('listed_taxa.id IN (?)', ids_for_listed_taxa_on_other_lists).paginate({:page => params[:missing_listings_page] || 1, :per_page => 20})
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

  def apply_missing_listings_scopes(listed_taxa_on_this_list, listed_taxa_on_other_lists, missing_filter_taxon, hide_ancestors, hide_descendants, missing_listings_list)
    scoped_list = listed_taxa_on_other_lists
    scoped_list = filter_by_list(missing_listings_list, scoped_list) if missing_listings_list
    scoped_list = missing_filter_taxon(missing_filter_taxon, scoped_list) if missing_filter_taxon
    scoped_list = hide_matches(listed_taxa_on_this_list, scoped_list)
    scoped_list = hide_descendants(listed_taxa_on_this_list, scoped_list) if hide_descendants
    scoped_list = hide_ancestors(listed_taxa_on_this_list, scoped_list) if hide_ancestors
    scoped_list
  end
  
  # filter out listed taxa that do not belong to a particular list
  # Note that "other_list" is a hash, not an active record query in progress
  def filter_by_list(list, other_list)
    other_list.select{|lt| 
      lt['list_id'].to_s == list.id.to_s
    }
  end

  def missing_filter_taxon(taxon, other_list)
    other_list.select{|lt| 
      found = taxon.match_descendants(lt)
    }
  end
  def hide_matches(this_list, other_list)
    this_list.each do |taxon|
      other_list = other_list.reject do |lt| 
        taxon['taxon_id'].to_i == lt['taxon_id'].to_i
      end
    end
    other_list
  end

  def hide_descendants(this_list, other_list)
    this_list.each do |taxon|
      other_list = other_list.reject do |lt| 
        Taxon.match_descendants_of_id(taxon['taxon_id'].to_i, lt)
      end
    end
    other_list
  end


  def hide_ancestors(this_list, other_list)
    this_list.each do |taxon|
      other_list = other_list.reject do |lt| 
        Taxon.match_descendants_of_id(lt['taxon_id'].to_i, taxon)
      end
    end
    other_list
  end

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
    return true unless @list.is_default?
    if logged_in? && current_user.is_admin?
      flash[:notice] = t(:you_can_edit_this_default_check_list_because)
      return true
    else
      flash[:error] = t(:you_cant_do_that_for_the_default_check_list_place)
      redirect_to @list
    end
  end
end
