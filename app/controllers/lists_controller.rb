class ListsController < ApplicationController
  include Shared::ListsModule
  include Shared::GuideModule

  before_filter :authenticate_user!, :except => [:index, :show, :by_login, :taxa, :guide,
    :cached_guide, :guide_widget]
  before_filter :authenticate_user!, only: [:show], if: Proc.new {|c| [:csv, :json].include?( c.request.format )}
  load_except = [ :index, :new, :create, :by_login ]
  before_filter :load_list, :except => load_except
  blocks_spam :except => load_except, :instance => :list
  check_spam only: [:create, :update], instance: :list
  before_filter :owner_required, :only => [:edit, :update, :destroy, 
    :remove_taxon]
  before_filter :require_listed_taxa_editor, :only => [:add_taxon_batch, :batch_edit]
  before_filter :load_user_by_login, :only => :by_login
  before_filter :admin_required, :only => [:add_from_observations_now, :refresh_now]
  before_filter :set_iconic_taxa, :only => [:show]

  caches_page :show, :if => Proc.new {|c| c.request.format == :csv}

  requires_privilege :speech, only: [:new, :create]

  LIST_SORTS = %w"id title"
  LIST_ORDERS = %w"asc desc"
  
  ## Custom actions ############################################################

  # gets lists by user login
  def by_login
    block_if_spammer(@selected_user) && return
    @prefs = current_preferences
    prefs_per_page = @prefs["per_page"] - 1
    @lists = @selected_user.personal_lists.
      order("#{@prefs["lists_by_login_sort"]} #{@prefs["lists_by_login_order"]}").
      paginate(:page => params["page"],
        :per_page =>prefs_per_page)
    
    # This is terribly inefficient. Might have to be smarter if there are
    # lots of lists.
    @iconic_taxa_for = {}
    @lists.each do |list|
      unless fragment_exist?(List.icon_preview_cache_key(list))
        taxon_ids = list.listed_taxa.select(:taxon_id).
          order("id desc").limit(50).map(&:taxon_id)
        unless taxon_ids.blank?
          phototaxa = Taxon.where(id: taxon_ids).includes(:photos)
          @iconic_taxa_for[list.id] = phototaxa[0...9]
        end
      end
    end
    
    respond_to do |format|
      format.html do
        render layout: "bootstrap"
      end
    end
  end
  
  # Compare two lists. Defaults to comparing the list in the URL with the
  # viewer's list.
  def compare
    @with = List.find_by_id(params[:with])
    @iconic_taxa = Taxon::ICONIC_TAXA
    
    unless @with
      flash[:notice] = t(:you_cant_compare_a_list_with_nothing)
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
    
    @paginating_listed_taxa = ListedTaxon.where(paginating_find_options[:conditions]).
      includes(paginating_find_options[:include]).
      paginate(page: paginating_find_options[:page], per_page: paginating_find_options[:per_page]).
      order(paginating_find_options[:order])
    
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
    @listed_taxa = ListedTaxon.where(find_options[:conditions]).
      includes(find_options[:include]).
      order(find_options[:order])
    
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
      ListedTaxon.distinct.where(place_id: @list.place_id).count(:taxon_id)
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
      if @listed_taxon = @list.listed_taxa.find_by_taxon_id(params[:taxon_id].to_i)
        @listed_taxon.destroy
        format.html do
          flash[:notice] = t(:taxon_removed_from_list)
          redirect_to @list
        end
        format.js do
          render :text => t(:taxon_removed_from_list)
        end
        format.json do
          render :json => @listed_taxon
        end
      else
        format.html do
          flash[:error] = t(:couldnt_find_that_taxon)
          redirect_to @list
        end
        format.js do
          render :status => :unprocessable_entity, 
            :text => "That taxon isn't in this list."
        end
        format.json do
          render :status => :unprocessable_entity, :json => {:error => "That taxon isn't in this list."}
        end
      end
    end
  end
  
  def add_from_observations_now
    delayed_task(@list.reload_from_observations_cache_key) do
      if job = @list.delay(priority: USER_PRIORITY,
        unique_hash: { "#{ @list.class.name }::add_observed_taxa": @list.id }
      ).add_observed_taxa(:force_update_cache_columns => true)
        Rails.cache.write(@list.reload_from_observations_cache_key, job.id)
        job
      end
    end
    
    respond_to_delayed_task(
      :done => "List reloaded from observations",
      :error => "Something went wrong reloading from observations",
      :timeout => "Reload timed out, please try again later"
    )
  end
  
  def refresh_now
    delayed_task(@list.refresh_cache_key) do
      if job = @list.delay(priority: USER_PRIORITY,
        unique_hash: { "#{ @list.class.name }::refresh": @list.id }
        ).refresh
        Rails.cache.write(@list.refresh_cache_key, job.id)
        job
      end
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
    @listed_taxa = @list.listed_taxa.where(taxon_id: @taxa).
      select("DISTINCT ON (taxon_id) listed_taxa.*")
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
    @job = Delayed::Job.find_by_id(@job_id) if @job_id && @job_id.is_a?(Integer)
    @tries = params[:tries].to_i
    @start = @tries == 0 && @job.blank?
    @done = @tries > 0 && @job.blank?
    @error = @job && !@job.failed_at.blank?
    @timeout = @tries > List::MAX_RELOAD_TRIES
    
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
      :processing => t(:processing3p)
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
      flash[:notice] = t(:only_the_owner_of_this_list_can_do_that)
      redirect_back_or_default('/')
      return false
    end
    if @list.is_a?(ProjectList)
      project = Project.find_by_id(@list.project_id)
      unless project.project_users.exists?(["role IN ('curator', 'manager') AND user_id = ?", current_user])
        flash[:notice] = t(:only_the_owner_of_this_list_can_do_that)
        redirect_back_or_default('/')
        return false
      end
    else
      unless @list.user_id == current_user.id || current_user.is_admin?
        flash[:notice] = t(:only_the_owner_of_this_list_can_do_that)
        redirect_back_or_default('/')
        return false
      end
    end
  end
  
end
