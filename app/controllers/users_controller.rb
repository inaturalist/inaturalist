#encoding: utf-8
class UsersController < ApplicationController  
  before_action :doorkeeper_authorize!,
    only: [ :create, :update, :edit, :dashboard, :new_updates, :api_token ],
    if: lambda { authenticate_with_oauth? }
  before_filter :authenticate_user!, 
    :unless => lambda { authenticated_with_oauth? },
    :except => [ :index, :show, :new, :create, :activate, :relationships, :search, :update_session ]
  load_only = [ :suspend, :unsuspend, :destroy, :purge,
    :show, :update, :relationships, :add_role, :remove_role, :set_spammer ]
  before_filter :find_user, :only => load_only
  # we want to load the user for set_spammer but not attempt any spam blocking,
  # because set_spammer may change the user's spammer properties
  blocks_spam :only => load_only - [ :set_spammer ], :instance => :user
  before_filter :ensure_user_is_current_user_or_admin, :only => [:update, :destroy]
  before_filter :admin_required, :only => [:curation]
  before_filter :curator_required, :only => [:suspend, :unsuspend, :set_spammer]
  before_filter :return_here, :only => [:index, :show, :relationships, :dashboard, :curation]
  before_filter :before_edit, only: [:edit, :edit_after_auth]
  
  MOBILIZED = [:show, :new, :create]
  before_filter :unmobilized, :except => MOBILIZED
  before_filter :mobilized, :only => MOBILIZED

  protect_from_forgery unless: -> {
    request.parameters[:action] == "search" && request.format.json? }

  caches_action :dashboard,
    expires_in: 15.minutes,
    cache_path: Proc.new {|c|
      c.send(
        :home_url,
        user_id: c.instance_variable_get("@current_user").id,
        ssl: c.request.ssl?
      )
    },
    if: Proc.new {|c|
      (c.params.keys - %w(action controller format)).blank?
    }

  caches_action :dashboard_updates,
    :expires_in => 15.minutes,
    :cache_path => Proc.new {|c|
      c.send(
        :dashboard_updates_url,
        :user_id => c.instance_variable_get("@current_user").id,
        :ssl => c.request.ssl?
      )
    },
    :if => Proc.new {|c| 
      (c.params.keys - %w(action controller format)).blank?
    }
  cache_sweeper :user_sweeper, :only => [:update]
  
  def new
    @user = User.new
  end
 
  def create
    logout_keeping_session!
    @user = User.new(params[:user])
    params[:user].each do |k,v|
      if k =~ /^prefer/
        params[:user].delete(k)
      else
        next
      end
      @user.send("#{k}=", v)
    end
    @user.register! if @user && @user.valid?
    success = @user && @user.valid?
    if success && @user.errors.empty?
      flash[:notice] = t(:please_check_for_you_confirmation_email, :site_name => CONFIG.site_name)
      self.current_user = @user
      redirect_back_or_default(dashboard_path)
    else
      respond_to do |format|
        format.html { render :action => 'new' }
        format.mobile { render :action => 'new' }
      end
    end
  end

  # this method should have been replaced by Devise, but there are probably some activation emails lingering in people's inboxes
  def activate
    user = current_user
    case
    when user && user.suspended?
      redirect_back_or_default('/')
    when (!params[:activation_code].blank?) && user && !user.confirmed?
      user.confirm!
      flash[:notice] = t(:your_account_has_been_verified, :site_name => CONFIG.site_name)
      if logged_in? && current_user.is_admin?
        redirect_back_or_default('/')
      else
        redirect_to '/login'
      end
    when params[:activation_code].blank?
      flash[:error] = t(:your_activation_code_was_missing)
      redirect_back_or_default('/')
    else 
      flash[:error]  = t(:we_couldnt_find_a_user_with_that_activation_code)
      redirect_back_or_default('/')
    end
  end

  # Don't take these out yet, useful for admin user management down the road

  def suspend
     @user.suspend!
     flash[:notice] = t(:the_user_x_has_been_suspended, :user => @user.login)
     redirect_back_or_default(@user)
  end
   
  def unsuspend
    @user.unsuspend!
    flash[:notice] = t(:the_user_x_has_been_unsuspended, :user => @user.login)
    redirect_back_or_default(@user)
  end
  
  def add_role
    unless @role = Role.find_by_name(params[:role])
      flash[:error] = t(:that_role_doesnt_exist)
      return redirect_to :back
    end
    
    if !current_user.has_role?(@role.name) || (@user.is_admin? && !current_user.is_admin?)
      flash[:error] = t(:you_dont_have_permission_to_do_that)
      return redirect_to :back
    end
    
    @user.roles << @role
    flash[:notice] = "Made #{@user.login} a(n) #{@role.name}"
    redirect_to :back
  end
  
  def remove_role
    unless @role = Role.find_by_name(params[:role])
      flash[:error] = t(:that_role_doesnt_exist)
      return redirect_to :back
    end
    
    unless current_user.has_role?(@role.name)
      flash[:error] = t(:you_dont_have_permission_to_do_that)
      return redirect_to :back
    end
    
    if @user.roles.delete(@role)
      flash[:notice] = "Removed #{@role.name} status from #{@user.login}"
    else
      flash[:error] = "#{@user.login} doesn't have #{@role.name} status"
    end
    redirect_to :back
  end
  
  def destroy
    @user.delay(priority: USER_PRIORITY,
      unique_hash: { "User::sane_destroy": @user.id }).sane_destroy
    sign_out(@user)
    flash[:notice] = "#{@user.login} has been removed from #{CONFIG.site_name} " + 
      "(it may take up to an hour to completely delete all associated content)"
    redirect_to root_path
  end

  def set_spammer
    if [ "true", "false" ].include?(params[:spammer])
      @user.update_attributes(spammer: params[:spammer])
      if params[:spammer] === "false"
        @user.flags_on_spam_content.each do |flag|
          flag.resolved = true
          flag.save!
        end
        @user.unsuspend!
      else
        @user.add_flag( flag: Flag::SPAM, user_id: current_user.id )
      end
    end
    redirect_to :back
  end

  # Methods below here are added by iNaturalist
  
  def index
    @recently_active_key = "recently_active_#{I18n.locale}_#{SITE_NAME}"
    unless fragment_exist?(@recently_active_key)
      @updates = []
      [Observation, Identification, Post, Comment].each do |klass|
        if klass == Observation && !@site.prefers_site_only_users?
          @updates += Observation.page_of_results( d1: 1.week.ago.to_s )
        else
          scope = klass.limit(30).
            order("#{klass.table_name}.id DESC").
            where("#{klass.table_name}.created_at > ?", 1.week.ago).
            joins(:user).
            where("users.id IS NOT NULL")
          scope = scope.where("users.site_id = ?", @site) if @site && @site.prefers_site_only_users?
          @updates += scope.all
        end
      end
      Observation.preload_associations(@updates, :user)
      @updates.delete_if do |u|
        (u.is_a?(Post) && u.draft?) || (u.is_a?(Identification) && u.taxon_change_id)
      end
      hash = {}
      @updates.sort_by(&:created_at).each do |record|
        hash[record.user_id] = record
      end
      @updates = hash.values.sort_by(&:created_at).reverse[0..11]
    end

    @leaderboard_key = "leaderboard_#{I18n.locale}_#{SITE_NAME}_4"
    unless fragment_exist?(@leaderboard_key)
      @most_observations = most_observations(:per => 'month')
      @most_species = most_species(:per => 'month')
      @most_identifications = most_identifications(:per => 'month')
      @most_observations_year = most_observations(:per => 'year')
      @most_species_year = most_species(:per => 'year')
      @most_identifications_year = most_identifications(:per => 'year')
    end

    @curators_key = "users_index_curators_#{I18n.locale}_#{SITE_NAME}_4"
    unless fragment_exist?(@curators_key)
      @curators = User.curators.limit(500).includes(:roles)
      @curators = @curators.where("users.site_id = ?", @site) if @site && @site.prefers_site_only_users?
      @curators = @curators.reject(&:is_admin?)
      @updated_taxa_counts = Taxon.where("updater_id IN (?)", @curators).group(:updater_id).count
      @taxon_change_counts = TaxonChange.where("user_id IN (?)", @curators).group(:user_id).count
      @resolved_flag_counts = Flag.where("resolver_id IN (?)", @curators).group(:resolver_id).count
    end

    respond_to do |format|
      format.html
    end
  end

  def leaderboard
    @year = (params[:year] || Time.now.year).to_i
    @month = params[:month].to_i unless params[:month].blank?
    @date = Date.parse("#{@year}-#{@month || '01'}-01")
    @time_unit = params[:month].blank? ? 'year' : 'month'
    @leaderboard_key = "leaderboard_#{I18n.locale}_#{SITE_NAME}_#{@year}_#{@month}"
    unless fragment_exist?(@leaderboard_key)
      if params[:month].blank?
        @most_observations = most_observations(:per => 'year', :year => @year)
        @most_species = most_species(:per => 'year', :year => @year)
        @most_identifications = most_identifications(:per => 'year', :year => @year)
      else
        @most_observations = most_observations(:per => 'month', :year => @year, :month => @month)
        @most_species = most_species(:per => 'month', :year => @year, :month => @month)
        @most_identifications = most_identifications(:per => 'month', :year => @year, :month => @month)
      end
    end
  end

  def search
    scope = User.active
    @q = params[:q].to_s
    escaped_q = @q.gsub(/(%|_)/){ |m| "\\" + m }
    unless @q.blank?
      wildcard_q = (@q.size == 1 ? "#{escaped_q}%" : "%#{escaped_q.downcase}%")
      if logged_in? && @q =~ Devise.email_regexp
        conditions = ["email = ?", @q]
        exact_conditions = conditions
      elsif @q =~ /\w+\s+\w+/
        conditions = ["lower(name) LIKE ?", wildcard_q]
        exact_conditions = ["lower(name) = ?", @q]
      else
        conditions = ["lower(login) LIKE ? OR lower(name) LIKE ?", wildcard_q, wildcard_q]
        exact_conditions = ["lower(login) = ? OR lower(name) = ?", @q, @q]
      end
      exact_ids = User.active.where(exact_conditions).pluck(:id)
      scope = scope.where(conditions)
    end
    if params[:order] == "activity"
      scope = scope.order("(observations_count + identifications_count + journal_posts_count) desc")
    else
      if exact_ids.blank?
        scope = scope.order("login")
      else
        scope = scope.select("*, (id IN (#{exact_ids.join(',')})) as is_exact")
        scope = scope.order("is_exact DESC, login ASC")
      end
    end
    params[:per_page] = params[:per_page] || 30
    params[:per_page] = 30 if params[:per_page].to_i > 30
    params[:per_page] = 1 if params[:per_page].to_i < 1
    params[:page] = params[:page] || 1
    params[:page] = 1 if params[:page].to_i < 1
    offset = (params[:page].to_i - 1) * params[:per_page].to_i
    respond_to do |format|
      format.html {
        # will_paginate collection will have total_entries
        @users = scope.paginate(page: params[:page], per_page: params[:per_page])
        counts_for_users
      }
      format.json do
        # use .limit.offset to avoid a slow count(), since count isn't used
        @users = scope.limit(params[:per_page]).offset(offset)
        haml_pretty do
          @users.each_with_index do |user, i|
            @users[i].html = view_context.render_in_format(:html, :partial => "users/chooser", :object => user).gsub(/\n/, '')
          end
        end
        render :json => @users.to_json(User.default_json_options.merge(:methods => [:html])),
          callback: params[:callback]
      end
    end
  end
  
  def show
    @selected_user = @user
    @login = @selected_user.login
    @followees = @selected_user.friends.paginate(:page => 1, :per_page => 15).order("id desc")
    @favorites_list = @selected_user.lists.find_by_title("Favorites")
    @favorites_list ||= @selected_user.lists.find_by_title(t(:favorites))
    if @favorites_list
      @favorite_listed_taxa = @favorites_list.listed_taxa.
        includes(taxon: [:photos, :taxon_names ]).
        paginate(page: 1, per_page: 15).order("listed_taxa.id desc")
    end

    respond_to do |format|
      format.html do
        @shareable_image_url = FakeView.image_url(@selected_user.icon.url(:original))
        @shareable_description = @selected_user.description
        @shareable_description = I18n.t(:user_is_a_naturalist, :user => @selected_user.login) if @shareable_description.blank?
        render layout: "bootstrap"
      end
      format.json { render :json => @selected_user.to_json(User.default_json_options) }
      format.mobile
    end
  end
  
  def relationships
    @users = if params[:following]
      @user.friends.paginate(page: params[:page] || 1).order(:login)
    else
      @user.followers.paginate(page: params[:page] || 1).order(:login)
    end
    counts_for_users
  end
  
  def get_nearby_taxa_obs_counts search_params
    elastic_params =  Observation.params_to_elastic_query(search_params)
    species_counts = Observation.elastic_search(elastic_params.merge(size: 0, aggregate: { species: { "taxon.id": 4 } })).response.aggregations
    nearby_taxa_results = species_counts.species.buckets
  end
  
  def get_local_onboarding_content
    local_onboarding_content = {local_results: false, target_taxa: nil, to_follows: nil}
    if (current_user.latitude.nil? || current_user.longitude.nil?) #show global content
      search_params = { verifiable: true, d1: 12.months.ago.to_s, d2: Time.now, rank: 'species' }
      nearby_taxa_results = get_nearby_taxa_obs_counts( search_params )
      local_onboarding_content[:local_results] = false
    else #have latitude and longitude so show local content
      if current_user.lat_lon_acc_admin_level == 0 || current_user.lat_lon_acc_admin_level == 1 #use place_id to fetch content from country or state
        place = Place.containing_lat_lng(current_user.latitude, current_user.longitude).where(admin_level: current_user.lat_lon_acc_admin_level).first
        if place
          search_params = { verifiable: true, place_id: place.id, d1: 12.months.ago.to_s, d2: Time.now, rank: 'species' }
          nearby_taxa_results = get_nearby_taxa_obs_counts(search_params)
          nearby_taxa_obs_count = nearby_taxa_results.map{ |b| b["doc_count"] }.sum
        else
          nearby_taxa_obs_count = 0
        end
      else #use lat-lon and radius to fetch content
        local_onboarding_content[:local_results] = true        
        search_params = { verifiable: true, lat: current_user.latitude, lng: current_user.longitude, radius: 1, d1: 12.months.ago.to_s, d2: Time.now, rank: 'species' }
        nearby_taxa_results = get_nearby_taxa_obs_counts(search_params)
        nearby_taxa_obs_count = nearby_taxa_results.map{ |b| b["doc_count"] }.sum
        if nearby_taxa_obs_count < 50
          search_params[:radius] = 100  # expand radius
          nearby_taxa_results = get_nearby_taxa_obs_counts(search_params)
          nearby_taxa_obs_count = nearby_taxa_results.map{ |b| b["doc_count"] }.sum
          if nearby_taxa_obs_count < 50
            search_params[:d1] = 12.months.ago.to_s  # expand time period
            nearby_taxa_results = get_nearby_taxa_obs_counts(search_params)
            nearby_taxa_obs_count = nearby_taxa_results.map{ |b| b["doc_count"] }.sum
            if nearby_taxa_obs_count < 50
              search_params[:radius] = 1000 # expand radius
              nearby_taxa_results = get_nearby_taxa_obs_counts(search_params)
              nearby_taxa_obs_count = nearby_taxa_results.map{ |b| b["doc_count"] }.sum
            end
          end
        end
      end
      if nearby_taxa_obs_count < 50 #not enough content so settle for global results
        search_params = { verifiable: true, d1: 12.months.ago.to_s, d2: Time.now, rank: 'species' }
        nearby_taxa_results = get_nearby_taxa_obs_counts(search_params)
        local_onboarding_content[:local_results] = false
      end
    end
    
    #fetch target_taxa from results
    target_taxa_ids = nearby_taxa_results.map{ |b| b["key"] }
    target_taxa = Taxon.where("id IN (?)", target_taxa_ids)
    local_onboarding_content[:target_taxa] = target_taxa if target_taxa.length > 0

    #fetch followers from results
    follower_ids = Observation.elastic_user_observation_counts(Observation.params_to_elastic_query(search_params), 4)[:counts].map{|u| u["user_id"]}
    follower_ids.delete(current_user.id) #exclude the current user
    followers = User.where("id IN (?)", follower_ids)
    local_onboarding_content[:to_follows] = followers if followers.length > 0

    return local_onboarding_content
  end

  def dashboard_updates
    filters = [ ]
    wheres = { }
    if params[:from]
      filters << { range: { id: { lt: params[:from] } } }
    end
    unless params[:notifier_type].blank?
      wheres[:notifier_type] = params[:notifier_type]
    end
    if params[:filter] == "you"
      wheres[:resource_owner_id] = current_user.id
      @you = true
    end
    if params[:filter] == "following"
      wheres[:notification] = %w(created_observations new_observations)
    end
    
    @pagination_updates = current_user.recent_notifications(
      filters: filters, wheres: wheres, per_page: 50)
    @updates = UpdateAction.load_additional_activity_updates(@pagination_updates, current_user.id)
    UpdateAction.preload_associations(@updates, [ :resource, :notifier, :resource_owner ])
    obs = UpdateAction.components_of_class(Observation, @updates)
    taxa = UpdateAction.components_of_class(Taxon, @updates)
    with_taxa = UpdateAction.components_with_assoc(:taxon, @updates)
    with_user = UpdateAction.components_with_assoc(:user, @updates)
    Observation.preload_associations(obs, [:comments, :identifications, :photos])
    with_taxa += obs.map(&:identifications).flatten
    with_user += obs.map(&:identifications).flatten + obs.map(&:comments).flatten
    Taxon.preload_associations(with_taxa, :taxon)
    taxa += with_taxa.map(&:taxon)
    Taxon.preload_associations(taxa, { taxon_names: :place_taxon_names })
    User.preload_associations(with_user, :user)
    @updates.delete_if{ |u| u.resource.nil? || u.notifier.nil? }
    @grouped_updates = UpdateAction.group_and_sort(@updates, hour_groups: true)
    respond_to do |format|
      format.html do
        render :partial => 'dashboard_updates', :layout => false
      end
    end
  end
  
  def dashboard
    @has_updates = (current_user.recent_notifications.count > 0)
    # onboarding content not shown in the dashboard if a user has updates
    @local_onboarding_content = @has_updates ? nil : get_local_onboarding_content
    respond_to do |format|
      format.html do
        scope = Announcement.
          where( 'placement LIKE \'users/dashboard%\' AND ? BETWEEN "start" AND "end"', Time.now.utc ).
          limit( 5 )
        base_scope = scope
        scope = scope.where( site_id: nil )
        @announcements = scope.in_locale( I18n.locale )
        @announcements = scope.in_locale( I18n.locale.to_s.split('-').first ) if @announcements.blank?
        @announcements = base_scope.where( site_id: @site ) if @announcements.blank?
        @subscriptions = current_user.subscriptions.includes(:resource).
          where("resource_type in ('Place', 'Taxon')").
          order("subscriptions.id DESC").
          limit(5)
        if current_user.is_curator? || current_user.is_admin?
          @flags = Flag.order("id desc").where("resolved = ? AND (user_id != 0 OR (user_id = 0 AND flaggable_type = 'Taxon'))", false).
            includes(:user, :resolver, :comments).limit(5)
          @ungrafted_taxa = Taxon.order("id desc").where("ancestry IS NULL").
            includes(:taxon_names).limit(5).active
        end
        render layout: "bootstrap"
      end
    end
  end
  
  def updates_count
    count = current_user.recent_notifications(unviewed: true,
      wheres: { notification: [ :activity, :mention ] }, per_page: 1).total_entries
    session[:updates_count] = count
    render :json => {:count => count}
  end
  
  def new_updates
    params[:notification] ||= "activity"
    params[:notification] = params[:notification].split(",")
    wheres = { notification: params[:notification] }
    notifier_types = [(params[:notifier_types] || params[:notifier_type])].compact
    unless notifier_types.blank?
      notifier_types = notifier_types.map{|t| t.split(',')}.flatten.compact.uniq
      wheres[:notifier_type] = notifier_types.map(&:downcase)
    end
    unless params[:resource_type].blank?
      wheres[:resource_type] = params[:resource_type].downcase
    end
    @updates = current_user.recent_notifications(unviewed: true, per_page: 200, wheres: wheres)
    unless request.format.json?
      if @updates.count == 0
        @updates = current_user.recent_notifications(viewed: true, per_page: 10, wheres: wheres)
      end
      if @updates.count == 0
        @updates = current_user.recent_notifications(per_page: 5, wheres: wheres)
      end
    end
    if !%w(1 yes y true t).include?(params[:skip_view].to_s)
      UpdateAction.user_viewed_updates(@updates, current_user.id)
      session[:updates_count] = 0
    end
    UpdateAction.preload_associations(@updates, [ :resource, :notifier, :resource_owner ])
    @updates = @updates.sort_by{|u| u.created_at.to_i * -1}
    respond_to do |format|
      format.html { render :layout => false }
      format.json { render :json => @updates }
    end
  end
  
  def edit
    respond_to do |format|
      format.html
      format.json do
        render :json => @user.to_json(
          :except => [
            :crypted_password, :salt, :old_preferences, :activation_code,
            :remember_token, :last_ip, :suspended_at, :suspension_reason,
            :icon_content_type, :icon_file_name, :icon_file_size,
            :icon_updated_at, :deleted_at, :remember_token_expires_at, :icon_url, :latitude, :longitude, :lat_lon_acc_admin_level
          ],
          :methods => [
            :user_icon_url, :medium_user_icon_url, :original_user_icon_url
          ]
        )
      end
    end
  end

  # this is the page that's shown after a new user is created via 3rd party provider_authorization
  # allows user to pick a new username if he doesn't like the one we autogenerated.
  def edit_after_auth
    redirect_to "/" and return unless (flash[:allow_edit_after_auth] || params[:test])
  end
  
  def update
    @display_user = current_user
    @login = @display_user.login
    @original_user = @display_user
    
    return add_friend unless params[:friend_id].blank?
    return remove_friend unless params[:remove_friend_id].blank?
    return update_password unless (params[:password].blank? && params[:commit] !~ /password/i)
    
    # Nix the icon_url if an icon file was provided
    @display_user.icon_url = nil if params[:user].try(:[], :icon)
    @display_user.icon = nil if params[:icon_delete]
    
    locale_was = @display_user.locale
    preferred_project_addition_by_was = @display_user.preferred_project_addition_by

    @display_user.assign_attributes( whitelist_params ) unless whitelist_params.blank?
    if @display_user.save
      # user changed their project addition rules and nothing else, so
      # updated_at wasn't touched on user. Set set updated_at on the user
      if @display_user.preferred_project_addition_by != preferred_project_addition_by_was &&
         @display_user.previous_changes.empty?
        @display_user.update_columns(updated_at: Time.now)
      end
      sign_in @display_user, :bypass => true
      respond_to do |format|
        format.html do
          if locale_was != @display_user.locale
            session[:locale] = @display_user.locale
          end

          if params[:from_edit_after_auth].blank?
            flash[:notice] = t(:your_profile_was_successfully_updated)
            redirect_back_or_default(person_by_login_path(:login => current_user.login))
          else
            redirect_to(dashboard_path)
          end
        end
        format.json do
          render :json => @display_user.to_json(User.default_json_options)
        end
      end
    else
      @display_user.login = @display_user.login_was unless @display_user.errors[:login].blank?
      respond_to do |format|
        format.html do
          before_edit
          if request.env['HTTP_REFERER'] =~ /edit_after_auth/
            render :action => 'edit_after_auth', :login => @original_user.login
          else
            render :action => 'edit', :login => @original_user.login
          end
        end
        format.json do
          render :json => {:errors => @display_user.errors}, :status => :unprocessable_entity
        end
      end
    end
  end
  
  def curation
    if params[:id].blank?
      @users = User.paginate(page: params[:page]).order(id: :desc)
      @comment_counts_by_user_id = Comment.where(user_id: @users).group(:user_id).count
    else
      @display_user = User.find_by_id(params[:id].to_i)
      @display_user ||= User.find_by_login(params[:id])
      @display_user ||= User.find_by_email(params[:id])
      if @display_user.blank?
        flash[:error] = t(:couldnt_find_a_user_matching_x_param, :id => params[:id])
      else
        @observations = Observation.page_of_results( user_id: @display_user.id )
      end
    end
  end

  def update_session
    allowed_patterns = [
      /^show_quality_metrics$/,
      /^user-seen-ann*/,
      /^prefers_*/
    ]
    updates = params.select {|k,v|
      allowed_patterns.detect{|p| 
        k.match(p)
      }
    }.symbolize_keys
    updates.each do |k,v|
      v = true if v.yesish?
      v = false if v.noish?
      session[k] = v
      if k =~ /^prefers_/ && logged_in? && current_user.respond_to?(k)
        current_user.update_attributes(k => v)
      end
    end
    render :head => :no_content, :layout => false, :text => nil
  end

  def api_token
    render json: { api_token: JsonWebToken.encode(user_id: current_user.id) }
  end

  def join_test
    groups = ( current_user.test_groups_array + [params[:test]] ).compact.uniq
    current_user.update_attributes( test_groups: groups.join( "|" ) )
    redirect_back_or_default( root_path )
  end

  def leave_test
    groups = ( current_user.test_groups_array - [params[:test]] ).compact.uniq
    current_user.update_attributes( test_groups: groups.join( "|" ) )
    redirect_back_or_default( root_path )
  end

protected

  def add_friend
    error_msg, notice_msg = [nil, nil]
    friend_user = User.find_by_id(params[:friend_id])
    if friend_user.blank? || friendship = current_user.friendships.find_by_friend_id(friend_user.id)
      error_msg = t(:either_that_user_doesnt_exist_or)
    else
      notice_msg = t(:you_are_now_following_x, :friend_user => friend_user.login)
      friendship = current_user.friendships.create(:friend => friend_user)
    end
    respond_to do |format|
      format.html do
        flash[:error] = error_msg
        flash[:notice] = notice_msg
        redirect_back_or_default(person_by_login_path(:login => current_user.login))
      end
      format.json { render :json => {:msg => error_msg || notice_msg, :friendship => friendship} }
    end
  end
  
  def remove_friend
    error_msg, notice_msg = [nil, nil]
    if friendship = current_user.friendships.find_by_friend_id(params[:remove_friend_id])
      notice_msg = t(:you_are_no_longer_following_x, :friend => friendship.friend.login)
      friendship.destroy
    else
      error_msg = t(:you_arent_following_that_person)
    end
    respond_to do |format|
      format.html do
        flash[:error] = error_msg
        flash[:notice] = notice_msg
        redirect_back_or_default(person_by_login_path(:login => current_user.login))
      end
      format.json { render :json => {:msg => error_msg || notice_msg, :friendship => friendship} }
    end
  end
  
  def update_password
    if params[:password].blank? || params[:password_confirmation].blank?
      flash[:error] = t(:you_must_specify_and_confirm_a_new_password)
      return redirect_to(edit_person_path(@user))
    end
    
    current_user.password = params[:password]
    current_user.password_confirmation = params[:password_confirmation]
    begin
      current_user.save!
      flash[:notice] = t(:successfully_changed_your_password)
    rescue ActiveRecord::RecordInvalid => e
      flash[:error] = t(:couldnt_change_your_password, :e => e)
      return redirect_to(edit_person_path(@user))
    end
    redirect_to(person_by_login_path(:login => current_user.login))
  end
  
  def find_user
    params[:id] ||= params[:login]
    begin
      @user = User.find(params[:id])
    rescue
      @user = User.where("lower(login) = ?", params[:id].to_s.downcase).first
      render_404 if @user.blank?
    end
  end
  
  def ensure_user_is_current_user_or_admin
    unless current_user.has_role? :admin
      redirect_to edit_user_path(current_user, :id => current_user.login) if @user.id != current_user.id
    end
  end
  
  def counts_for_users
    @observation_counts = Observation.where(user_id: @users.to_a).group(:user_id).count
    @listed_taxa_counts = ListedTaxon.where(list_id: @users.to_a.map{|u| u.life_list_id}).
      group(:user_id).count
    @post_counts = Post.where(user_id: @users.to_a).group(:user_id).count
  end
  
  def activity_object_image_url(activity_stream)
    o = activity_stream.activity_object
    case o.class.to_s
    when "Observation"
      o.photos.first.try(:square_url)
    when ""
      nil
    end
  end

  def most_observations(options = {})
    per = options[:per] || 'month'
    year = options[:year] || Time.now.year
    month = options[:month] || Time.now.month
    if per == 'month'
      elastic_params = { observed_on_year: year, observed_on_month: month }
    else
      elastic_params = { observed_on_year: year }
    end
    elastic_params[:site_id] = @site.id if @site && @site.prefers_site_only_users?
    elastic_query = Observation.params_to_elastic_query(elastic_params)
    counts = Observation.elastic_user_observation_counts(elastic_query, 5)
    user_counts = Hash[ counts[:counts].map{ |c| [ c["user_id"], c["count_all"] ] } ]
    users = User.where(id: user_counts.keys).group_by(&:id)
    Hash[ user_counts.map{ |id,c| [ users[id].first, c ] } ]
  end

  def most_species(options = {})
    per = options[:per] || 'month'
    year = options[:year] || Time.now.year
    month = options[:month] || Time.now.month
    if per == 'month'
      elastic_params = { observed_on_year: year, observed_on_month: month }
    else
      elastic_params = { observed_on_year: year }
    end
    elastic_params[:site_id] = @site.id if @site && @site.prefers_site_only_users?
    elastic_query = Observation.params_to_elastic_query(elastic_params)
    counts = Observation.elastic_user_taxon_counts(elastic_query, limit: 5, batch: false)
    user_counts = Hash[ counts.map{ |c| [ c["user_id"], c["count_all"] ] } ]
    users = User.where(id: user_counts.keys).group_by(&:id)
    Hash[ user_counts.map{ |id,c| [ users[id].first, c ] } ]
  end

  def most_identifications(options = {})
    per = options[:per] || 'month'
    year = options[:year] || Time.now.year
    month = options[:month] || Time.now.month
    site_filter = @site && @site.prefers_site_only_users?
    filters = [ { term: { own_observation: false } } ]
    if per == 'month'
      date = Date.parse("#{ year }-#{ month }-1")
      filters << { range: { created_at: {
        gte: date,
        lte: date + 1.month
      }}}
    else
      date = Date.parse("#{ year }-1-1")
      filters << { range: { created_at: {
        gte: date,
        lte: date + 1.year
      }}}
    end

    result = Identification.elastic_search(
      filters: filters,
      size: 0,
      aggregate: {
        obs: {
          terms: { field: "user.id", size: site_filter ? 200 : 20 }
        }
      }
    )

    user_counts = result.response.aggregations.obs.
      buckets.map{ |b| { user_id: b["key"], count: b["doc_count"] } }
    users_scope = User.where(id: user_counts.map{ |uc| uc[:user_id] })
    if @site && @site.prefers_site_only_users?
      # only return users associated with the site
      users_scope = users_scope.where(site_id: @site.id)
    end
    users = Hash[users_scope.map{ |u| [ u.id, u ] }]
    # assign user instances into their user_counts
    user_counts.each{ |uc| uc[:user] = users[uc[:user_id]] if users[uc[:user_id]] }
    # return the top 5 user_counts with users
    Hash[user_counts.select{ |uc| uc[:user] }[0...5].map{ |uc| [ uc[:user], uc[:count] ]}]
  end

  def whitelist_params
    return if params[:user].blank?
    params.require(:user).permit(
      :description,
      :email,
      :icon,
      :icon_url,
      :lists_by_login_order,
      :lists_by_login_sort,
      :locale,
      :login,
      :make_observation_licenses_same,
      :make_photo_licenses_same,
      :make_sound_licenses_same,
      :name,
      :password,
      :password_confirmation,
      :per_page,
      :place_id,
      :preferred_observation_fields_by,
      :preferred_observation_license,
      :preferred_observations_view,
      :preferred_photo_license,
      :preferred_project_addition_by,
      :preferred_sound_license,
      :prefers_comment_email_notification,
      :prefers_identification_email_notification,
      :prefers_message_email_notification,
      :prefers_project_invitation_email_notification,
      :prefers_project_journal_post_email_notification,
      :prefers_mention_email_notification,
      :prefers_share_observations_on_facebook,
      :prefers_share_observations_on_twitter,
      :prefers_no_email,
      :prefers_automatic_taxonomic_changes,
      :prefers_community_taxa,
      :prefers_location_details,
      :prefers_receive_mentions,
      :prefers_redundant_identification_notifications,
      :site_id,
      :test_groups,
      :time_zone
    )
  end

  def before_edit
    @user = current_user
    @sites = Site.live.limit(100)
    @user.site_id ||= Site.first.try(:id) unless @sites.blank?
  end

end
