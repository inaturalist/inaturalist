class ListsController < ApplicationController
  include Shared::ListsModule
  include Shared::GuideModule

  before_filter :login_required, :except => [:index, :show, :by_login, :taxa]  
  before_filter :load_list, :except => [:index, :new, :create, :by_login]
  before_filter :owner_required, :only => [:edit, :update, :destroy, 
    :remove_taxon, :add_taxon_batch, :reload_from_observations]
  before_filter :load_find_options, :only => [:show]
  before_filter :load_user_by_login, :only => :by_login
  
  caches_page :show, :if => Proc.new {|c| c.request.format.csv?}
  
  LIST_SORTS = %w"id title"
  LIST_ORDERS = %w"asc desc"
  
  ## Custom actions ############################################################

  # gets lists by user login
  def by_login
    @prefs = current_preferences
    
    @life_list = @selected_user.life_list
    @lists = @selected_user.lists.paginate(:page => params[:page], 
      :per_page => @prefs["per_page"], 
      :order => "#{@prefs["lists_by_login_sort"]} #{@prefs["lists_by_login_order"]}")
    
    # This is terribly inefficient. Might have to be smarter if there are
    # lots of lists.
    @iconic_taxa_for = {}
    @lists.each do |list|
      unless fragment_exist?(List.icon_preview_cache_key(list))
        taxon_ids = list.listed_taxa.all(
          :select => "taxon_id", 
          :order => "id desc", :limit => 50).map(&:taxon_id)
        unless taxon_ids.blank?
          phototaxa = Taxon.all(:include => :photos,
            :conditions => ["taxa.id IN (?)", taxon_ids])
          @iconic_taxa_for[list.id] = phototaxa[0...9]
        end
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
    @iconic_taxa = Taxon::ICONIC_TAXA
    
    unless @with
      flash[:notice] = "You can't compare a list with nothing!"
      return redirect_to(list_path(@list))
    end
    
    find_options = {
      :include => [:taxon],
      :order => "taxa.ancestry"
    }
    
    # Load listed taxa for pagination
    paginating_find_options = find_options.merge(
      :page => params[:page], 
      :per_page => 26)
      
    left_condition = ["list_id = ?", @list]
    right_condition = ["list_id = ?", @with]
    both_condition = ["list_id in (?)", [@list, @with].compact]

    # TODO: pull out check list logic
    if @list.is_a?(CheckList) && @list.is_default?
      left_condition = ["place_id = ?", @list.place_id]
      both_condition = ["(place_id = ? OR list_id = ?)", @list.place_id, @with]
    end
    
    @show_list = params[:show] if %w(left right).include?(params[:show])
    list_conditions = case @show_list
    when "left"   then  left_condition
    when "right"  then  right_condition
    else                both_condition
    end
    
    paginating_find_options[:conditions] = list_conditions
    
    # Handle iconic taxon filtering
    if params[:taxon]
      @filter_taxon = Taxon.find_by_id(params[:taxon])
      paginating_find_options[:conditions] = update_conditions(paginating_find_options[:conditions], 
        ["AND taxa.iconic_taxon_id = ?", @filter_taxon])
    end
    
    @paginating_listed_taxa = ListedTaxon.paginate(paginating_find_options)
    
    # Load the listed taxa for display.  The reason we do diplay and paginating
    # listed taxa is that strictly paginating and ordering by lft would sometimes
    # leave some taxa off the end.  Say you grabbed 26 listed_taxa and the last in
    # list1 was a Snowy Egret, but since list2 actually had more taxa than list1
    # on this page, the page didn't include list2's snowy egret, b/c it would be
    # on the next page.  I know, I'm confused even writing it.  KMU 2009-02-08
    find_options[:conditions] = update_conditions(both_condition, 
      ["AND listed_taxa.taxon_id IN (?)", @paginating_listed_taxa.map(&:taxon_id)])
    find_options[:include] = [
      :last_observation,
      {:taxon => [:iconic_taxon, :photos, :taxon_names]}
    ]
    @listed_taxa = ListedTaxon.all(find_options)
    
    
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
    
    load_listed_taxon_photos
  end
  
  def remove_taxon    
    respond_to do |format|
      if @listed_taxon = @list.listed_taxa.find_by_taxon_id(params[:taxon_id].to_i)
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
  
  def reload_from_observations
    delayed_task(@list.reload_from_observations_cache_key) do
      @list.reload_from_observations
    end
    
    respond_to_delayed_task(
      :done => "List reloaded from observations",
      :error => "Something went wrong reloading from observations",
      :timeout => "Reload timed out, please try again later"
    )
  end
  
  def refresh
    delayed_task(@list.refresh_cache_key) do
      job = @list.send_later(:refresh, :skip_update_cache_columns => true)
      Rails.cache.write(@list.refresh_cache_key, job.id)
      job
    end
    
    respond_to_delayed_task(
      :done => "List rules re-applied",
      :error => "Something went wrong re-applying list rules",
      :timeout => "Re-applying list rules timed out, please try again later"
    )
  end
  
  def guide
    show_guide do |scope|
      scope = scope.on_list(@list)
    end
    @listed_taxa = @list.listed_taxa.all(
      :select => "DISTINCT ON (taxon_id) listed_taxa.*", 
      :conditions => ["taxon_id IN (?)", @taxa])
    @listed_taxa_by_taxon_id = @listed_taxa.index_by{|lt| lt.taxon_id}
    render :layout => false, :partial => @partial
  end
  
  def guide_widget
    @guide_url = url_for(:action => "guide", :id => @list)
    show_guide_widget
    render :template => "guides/guide_widget"
  end
  
  private
  
  # Takes a block that sets the @job instance var
  def delayed_task(cache_key)
    @job_id = Rails.cache.read(cache_key)
    @job = Delayed::Job.find_by_id(@job_id) if @job_id && @job_id.is_a?(Fixnum)
    Rails.logger.debug "[DEBUG] @job: #{@job}"
    @tries = params[:tries].to_i
    @start = @tries == 0 && @job.blank?
    @done = @tries > 0 && @job.blank?
    @error = @job && !@job.failed_at.blank?
    @timeout = @tries > LifeList::MAX_RELOAD_TRIES
    
    if @start
      @job = yield
    elsif @done || @error || @timeout
      Rails.cache.delete(cache_key)
    end
  end
  
  def respond_to_delayed_task(messages = {})
    @messages = {
      :done => "Success!",
      :error => "Something went wrong",
      :timeout => "Request timed out, please try again later",
      :processing => "Processing..."
    }.merge(messages)
    
    respond_to do |format|
      format.js do
        if @done
          flash[:notice] = messages[:done]
          render :status => :ok, :text => @messages[:done]
        elsif @error then render :status => :unprocessable_entity, :text => "#{@messages[:error]}: #{@job.last_error}"
        elsif @timeout then render :status => :request_timeout, :text => @messages[:timeout]
        else render :status => :created, :text => @messages[:processing]
        end
      end
    end
  end
  
  def owner_required
    unless logged_in?
      flash[:notice] = "Only the owner of this list can do that.  Don't be evil."
      redirect_back_or_default('/')
      return false
    end
    if @list.is_a?(ProjectList)
      project = Project.find_by_id(@list.project_id)
      unless project.project_users.exists?(["role IN ('curator', 'manager') AND user_id = ?", current_user])
        flash[:notice] = "Only the owner of this list can do that.  Don't be evil."
        redirect_back_or_default('/')
        return false
      end
    else
      unless @list.user.id == current_user.id || current_user.is_admin?
        flash[:notice] = "Only the owner of this list can do that.  Don't be evil."
        redirect_back_or_default('/')
        return false
      end
    end
  end
  
  def load_listed_taxon_photos
    @photos_by_listed_taxon_id = {}
    obs_ids = @listed_taxa.map(&:last_observation_id).compact
    obs_photos = ObservationPhoto.all(:select => "DISTINCT ON (observation_id) *", 
      :conditions => ["observation_id IN (?)", obs_ids], :include => [:photo])
    obs_photos_by_obs_id = obs_photos.index_by(&:observation_id)
    @listed_taxa.each do |lt|
      next unless (op = obs_photos_by_obs_id[lt.last_observation_id])
      @photos_by_listed_taxon_id[lt.id] = op.photo
    end
  end
end
