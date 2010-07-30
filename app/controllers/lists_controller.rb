class ListsController < ApplicationController
  include Shared::ListsModule

  before_filter :login_required, :except => [:index, :show, :by_login, :taxa]  
  before_filter :load_list, :only => [:show, :edit, :update, :destroy, 
    :compare, :remove_taxon, :add_taxon_batch, :taxa]
  before_filter :owner_required, :only => [:edit, :update, :destroy, 
    :remove_taxon, :add_taxon_batch]
  before_filter :load_find_options, :only => [:show]
  before_filter :load_user_by_login, :only => :by_login
  
  LIST_SORTS = %w"id title"
  LIST_ORDERS = %w"asc desc"
  
  ## Custom actions ############################################################

  # gets lists by user login
  def by_login
    @prefs = current_preferences
    
    @life_list = @selected_user.life_list
    @lists = @selected_user.lists.paginate(:page => params[:page], 
      :per_page => @prefs.per_page, 
      :order => "#{@prefs.lists_by_login_sort} #{@prefs.lists_by_login_order}")
    
    # This is terribly inefficient. Might have to be smarter if there are
    # lots of lists.
    @iconic_taxa_for = {}
    @lists.each do |list|
      unless fragment_exist?(List.icon_preview_cache_key(list))
        @iconic_taxa_for[list.id] = list.taxa.all(:include => :photos, 
          :limit => 9, :order => "photos.id DESC")
      end
    end
    
    respond_to do |format|
      format.html
    end
  end
  
  # Compare two lists. Defaults to comparing the list in the URL with the
  # viewer's list.
  def compare
    @with = List.find_by_id(params[:with])
    @with ||= current_user.life_list if logged_in?
    @iconic_taxa = Taxon.iconic_taxa.all(:order => 'rgt')
    
    unless @with
      flash[:notice] = "You can't compare a list with nothing!"
      return redirect_to(list_path(@list))
    end
    
    find_options = {
      :conditions => ["list_id in (?)", [@list, @with].compact],
      :include => [:taxon],
      :order => "taxa.ancestry"
    }
    
    # TODO: pull out check list logic
    if @list.is_a?(CheckList) && @list.is_default?
      find_options[:conditions] = ["(place_id = ? OR list_id = ?)", @list.place_id, @with]
    end
    
    # Handle iconic taxon filtering
    if params[:taxon]
      @filter_taxon = Taxon.find_by_id(params[:taxon])
      find_options[:conditions] = update_conditions(find_options[:conditions], 
        ["AND taxa.iconic_taxon_id = ?", @filter_taxon])
    end
    
    # Load listed taxa for pagination
    paginating_find_options = find_options.merge(
      :group => 'listed_taxa.taxon_id', 
      :page => params[:page], 
      :per_page => 26)
    @paginating_listed_taxa = ListedTaxon.paginate(paginating_find_options)
    
    # Load the listed taxa for display.  The reason we do diplay and paginating
    # listed taxa is that strictly paginating and ordering by lft would sometimes
    # leave some taxa off the end.  Say you grabbed 26 listed_taxa and the last in
    # list1 was a Snowy Egret, but since list2 actually had more taxa than list1
    # on this page, the page didn't include list2's snowy egret, b/c it would be
    # on the next page.  I know, I'm confused even writing it.  KMU 2009-02-08
    find_options[:conditions] = update_conditions(find_options[:conditions], 
      ["AND listed_taxa.taxon_id IN (?)", 
        @paginating_listed_taxa.map(&:taxon_id)]
    )
    find_options[:include] = [
      :last_observation,
      {:taxon => [:iconic_taxon, :photos, :taxon_names]}
    ]
    @listed_taxa = ListedTaxon.find(:all, find_options)
    
    
    # Group listed_taxa into owner / other pairs
    @pairs = []
    @listed_taxa.group_by(&:taxon_id).each do |taxon_id, listed_taxa|
      listed_taxa << nil if listed_taxa.size == 1
      if @list.is_a?(CheckList) && @list.is_default?
        listed_taxa.reverse! if listed_taxa.first.place_id != @list.place_id
      else
        listed_taxa.reverse! if listed_taxa.first.list_id != @list.id
      end
      @pairs << listed_taxa
    end
    
    # Calculate the stats
    # TODO: pull out check list logic
    @total_listed_taxa = if @list.is_a?(CheckList) && @list.is_default?
      ListedTaxon.count('DISTINCT(taxon_id)',
        :conditions => ["place_id = ?", @list.place_id])
    else
      @list.listed_taxa.count
    end
    @with_total_listed_taxa = @with.listed_taxa.count
    @max_total_listed_taxa = [@total_listed_taxa, @with_total_listed_taxa].max
    @iconic_taxon_counts = get_iconic_taxon_counts(@list, @iconic_taxa)
    @with_iconic_taxon_counts = get_iconic_taxon_counts(@with, @iconic_taxa)
    
    @iconic_taxon_counts_hash = {}
    @iconic_taxon_counts.each do |iconic_taxon, count|
      if iconic_taxon.nil?
        @iconic_taxon_counts_hash['Undefined'] = count
      else
        @iconic_taxon_counts_hash[iconic_taxon] = count
      end
    end
    
    @with_iconic_taxon_counts_hash = {}
    @with_iconic_taxon_counts.each do |iconic_taxon, count|
      if iconic_taxon.nil?
        @with_iconic_taxon_counts_hash['Undefined'] = count
      else
        @with_iconic_taxon_counts_hash[iconic_taxon] = count
      end
    end
    
    @paired_iconic_taxon_counts = @iconic_taxa.map do |iconic_taxon|
      pair = [
        @iconic_taxon_counts_hash[iconic_taxon], 
        @with_iconic_taxon_counts_hash[iconic_taxon]
      ]
      pair.compact.empty? ? nil : [iconic_taxon, pair]
    end.compact
  end
  
  def remove_taxon    
    respond_to do |format|
      if @listed_taxon = @list.listed_taxa.find_by_taxon_id(params[:taxon_id])
        @listed_taxon.destroy
        format.html do
          flash[:notice] = "Taxon removed from list."
          redirect_to @list
        end
        format.js do
          render :text => 'Taxon removed from list.'
        end
      else
        format.html do
          flash[:error] = "Could't find that taxon."
          redirect_to @list
        end
        format.js do
          render :status => :unprocessable_entity, 
            :text => "That taxon isn't in this list."
        end
      end
    end
  end
  
  private
  
  def owner_required
    unless logged_in? && @list.user.id == current_user.id
      flash[:notice] = "Only the owner of this list can do that.  " + 
                       "Don't be evil."
      redirect_to lists_by_login_path(@list.user.login)
    end
  end
end
