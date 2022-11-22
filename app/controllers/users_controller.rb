#encoding: utf-8
class UsersController < ApplicationController
  before_action -> { doorkeeper_authorize! :login, :write },
    only: [ :edit ],
    if: lambda { authenticate_with_oauth? }
  before_action -> { doorkeeper_authorize! :write },
    only: [ :create, :update, :dashboard, :new_updates, :api_token, :mute, :unmute, :block, :unblock ],
    if: lambda { authenticate_with_oauth? }
  before_action -> { doorkeeper_authorize! :account_delete },
    only: [ :destroy ],
    if: lambda { authenticate_with_oauth? }
  before_action :authenticate_user!,
    :unless => lambda { authenticated_with_oauth? },
    :except => [ :index, :show, :new, :create, :activate, :relationships,
      :search, :update_session, :parental_consent ]
  load_only = [ :suspend, :unsuspend, :destroy, :purge,
    :show, :update, :followers, :following, :relationships, :add_role,
    :remove_role, :set_spammer, :merge, :trust, :untrust, :mute, :unmute,
    :block, :unblock, :moderation
  ]
  before_action :find_user, :only => load_only
  # we want to load the user for set_spammer but not attempt any spam blocking,
  # because set_spammer may change the user's spammer properties
  blocks_spam :only => load_only - [ :set_spammer ], :instance => :user
  check_spam only: [:create, :update], instance: :user
  before_action :ensure_user_is_current_user_or_admin, :only => [:update, :destroy]
  before_action :admin_required, :only => [:curation, :merge]
  before_action :site_admin_of_user_required, only: [:add_role, :remove_role]
  before_action :curator_required, only: [
    :moderation,
    :recent,
    :set_spammer,
    :suspend,
    :unsuspend
  ]
  before_action :return_here, only: [
    :curation,
    :dashboard,
    :edit,
    :index,
    :moderation,
    :relationships,
    :show
  ]
  before_action :before_edit, only: [:edit, :edit_after_auth]
  skip_before_action :check_preferred_place, only: :api_token
  skip_before_action :preload_user_preferences, only: :api_token
  skip_before_action :set_site, only: :api_token
  skip_before_action :check_preferred_site, only: :api_token
  skip_before_action :set_ga_trackers, only: :api_token

  prepend_around_action :enable_replica, only: [:dashboard_updates, :show]

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

  def suspend
    if @user.suspended?
      flash[:error] = "You cannot suspend someone who is already suspended"
      return redirect_back_or_default person_path( @user )
    end
    @moderator_action = ModeratorAction.new(
      resource: @user,
      user: current_user,
      action: ModeratorAction::SUSPEND
    )
    render layout: "bootstrap"
  end
   
  def unsuspend
    unless @user.suspended?
      flash[:error] = "You cannot unsuspend someone who is not suspended"
      return redirect_back_or_default person_path( @user )
    end
    @moderator_action = ModeratorAction.new(
      resource: @user,
      user: current_user,
      action: ModeratorAction::UNSUSPEND
    )
    render layout: "bootstrap"
  end
  
  def add_role
    unless @role = Role.find_by_name(params[:role])
      flash[:error] = t(:that_role_doesnt_exist)
      return redirect_back_or_default @user
    end
    
    if @user.is_admin? && !current_user.is_admin?
      flash[:error] = t(:you_dont_have_permission_to_do_that)
      return redirect_back_or_default @user
    end

    @user.roles << @role
    if @role.name === Role::CURATOR
      @user.update( curator_sponsor: current_user )
    end
    flash[:notice] = "Added #{@role.name} status to #{@user.login}"
    redirect_back_or_default @user
  end
  
  def remove_role
    unless @role = Role.find_by_name(params[:role])
      flash[:error] = t(:that_role_doesnt_exist)
      return redirect_back_or_default @user
    end

    if @user.is_admin? && !current_user.is_admin?
      flash[:error] = t(:you_dont_have_permission_to_do_that)
      return redirect_back_or_default @user
    end

    if @user.roles.delete(@role)
      flash[:notice] = "Removed #{@role.name} status from #{@user.login}"
      if @role.name === Role::CURATOR
        @user.update( curator_sponsor: nil )
      end
    else
      flash[:error] = "#{@user.login} doesn't have #{@role.name} status"
    end
    redirect_back_or_default @user
  end

  def delete
    @observations_count = current_user.observations_count
    @helpers_count = INatAPIService.get( "/observations/identifiers",
      user_id: current_user.id, per_page: 0 ).total_results
    @comments_count = current_user.comments.count
    projects_with_managers_count = ProjectUser.
      joins(:project).
      where( "projects.user_id = ?", current_user ).
      where( role: ProjectUser::MANAGER ).
      where( "project_users.user_id != ?", current_user ).
      count( "DISTINCT project_id" )
    @projects_count = current_user.projects.count - projects_with_managers_count
    ident_response = Identification.elastic_search(
      size: 0,
      filters: [
        { term: { "user.id": current_user.id } },
        { term: { own_observation: false } },
        { term: { current: true } }
      ],
      aggregate: {
        distinct_obs_users: {
          cardinality: { field: "observation.user_id" }
        }
      },
      track_total_hits: true
    )
    @identifications_count = ident_response.total_entries
    @helpees_count = ident_response.response.aggregations.distinct_obs_users.value || 0
    respond_to do |format|
      format.html do
        render layout: "bootstrap"
      end
    end
  end
  
  def destroy
    if params[:confirmation].blank? || params[:confirmation_code].blank? || ( params[:confirmation] && params[:confirmation] != params[:confirmation_code] )
      msg = t( "views.users.delete.you_must_enter_confirmation_code_in_the_form", confirmation_code: params[:confirmation_code] )
      respond_to do |format|
        format.html do
          flash[:error] = msg
          redirect_to delete_users_path
        end
        format.json do
          render json: { error: msg }, status: :unprocessable_entity
        end
      end
      return
    end
    @user.delay(priority: USER_PRIORITY,
      unique_hash: { "User::sane_destroy": @user.id }).sane_destroy
    sign_out(@user) if current_user == @user
    respond_to do |format|
      format.html do
        flash[:notice] = "#{@user.login} has been removed from #{@site.name} " +
          "(it may take up to an hour to completely delete all associated content)"
        redirect_to root_path
      end
      format.json { head :no_content }
    end
  end

  def set_spammer
    if [ "true", "false" ].include?(params[:spammer])
      @user.update(spammer: params[:spammer])
      if params[:spammer] === "false"
        flash[:notice] = t(:user_flagged_as_a_non_spammer_html, user: helpers.link_to_user( @user ) )
        @user.flags_on_spam_content.each do |flag|
          flag.update(resolved: true, resolver: current_user)
        end
        @user.flags.where(flag: Flag::SPAM).update_all(resolved: true, resolver_id: current_user.id )
        @user.unsuspend!
      else
        flash[:notice] = t(:user_flagged_as_a_spammer_html, user: helpers.link_to_user( @user ) )
        @user.add_flag( flag: Flag::SPAM, user_id: current_user.id )
      end
    end
    redirect_back_or_default( @user )
  end

  # Methods below here are added by iNaturalist
  
  def index
    @recently_active_key = "recently_active_#{I18n.locale}_site_#{@site.id}"
    unless fragment_exist?(@recently_active_key)
      @updates = []
      [Observation, Identification, Post, Comment].each do |klass|
        if klass == Observation && !@site.prefers_site_only_users?
          @updates += Observation.page_of_results( d1: 1.week.ago.to_s )
        else
          scope = klass.limit(30).
            order("#{klass.table_name}.created_at DESC").
            where("#{klass.table_name}.created_at > ?", 1.week.ago).
            joins(:user).
            where("users.id IS NOT NULL")
          scope = scope.where("users.site_id = ?", @site) if @site && @site.prefers_site_only_users?
          @updates += scope.all
        end
      end
      Observation.preload_associations(@updates, :user)
      @updates.delete_if do |u|
        ( u.is_a?( Post ) && u.draft? ) ||
        ( u.is_a?( Identification ) && u.taxon_change_id ) ||
        ( u.is_a?( Identification ) && u.observation.user_id == u.user_id )
      end
      hash = {}
      @updates.sort_by(&:created_at).each do |record|
        hash[record.user_id] = record
      end
      @updates = hash.values.sort_by(&:created_at).reverse[0..11]
    end

    @leaderboard_key = "leaderboard_#{I18n.locale}_site_#{@site.id}_4"
    unless fragment_exist?(@leaderboard_key)
      @most_observations = most_observations(:per => 'month')
      @most_species = most_species(:per => 'month')
      @most_identifications = most_identifications(:per => 'month')
      @most_observations_year = most_observations(:per => 'year')
      @most_species_year = most_species(:per => 'year')
      @most_identifications_year = most_identifications(:per => 'year')
    end

    @curators_key = "users_index_curators_#{I18n.locale}_site_#{@site.id}_4"
    unless fragment_exist?(@curators_key)
      @curators = User.curators.limit(500).includes(:roles).order( "updated_at DESC" )
      @curators = @curators.where("users.site_id = ?", @site) if @site && @site.prefers_site_only_users?
      @curators = @curators.reject(&:is_admin?)
      @updated_taxa_counts = Taxon.where("updater_id IN (?)", @curators).group(:updater_id).count
      @taxon_change_counts = TaxonChange.where("user_id IN (?)", @curators).group(:user_id).count
      @resolved_flag_counts = Flag.where("resolver_id IN (?)", @curators).group(:resolver_id).count
      @curators = @curators.sort_by do |u|
        -1 * (
          @resolved_flag_counts[u.id].to_i +
          @updated_taxa_counts[u.id].to_i +
          @taxon_change_counts[u.id].to_i
        )
      end
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
    @leaderboard_key = "leaderboard_#{I18n.locale}_site_#{@site.id}_#{@year}_#{@month}"
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
  
  def show
    @selected_user = @user
    @login = @selected_user.login
    @followees = @selected_user.followees.page( 1 ).per_page( 15 ).order( "users.id desc" )
    @favorites_list = @selected_user.lists.find_by_title("Favorites")
    @favorites_list ||= @selected_user.lists.find_by_title(t(:favorites))
    if @favorites_list
      @favorite_listed_taxa = @favorites_list.listed_taxa.
        includes(taxon: [:photos, :taxon_names ]).
        paginate(page: 1, per_page: 15).order("listed_taxa.id desc")
    end

    respond_to do |format|
      format.html do
        @shareable_image_url = helpers.image_url(@selected_user.icon.url(:original))
        @shareable_description = @selected_user.description
        @shareable_description = I18n.t(:user_is_a_naturalist, :user => @selected_user.login) if @shareable_description.blank?
        if @selected_user.last_active.blank?
          times = [
            Observation.elastic_query(
              user_id: @selected_user.id,
              order_by: "created_at",
              order: "desc"
            ).first.try(&:created_at)
          ]
          idents = INatAPIService.identifications(
            user_id: @selected_user.id,
            order_by: "created_at",
            order: "desc",
            is_change: false
          )
          if idents && idents.results
            times << idents.results.first.try(:[], "created_at" ).try(:to_time)
          end
          @selected_user.last_active = times.compact.sort.map{|t| t.in_time_zone( Time.zone ).to_date }.last
        end
        @donor_since = @selected_user.display_donor_since ? @selected_user.display_donor_since.to_date : nil
        render layout: "bootstrap"
      end
      opts = User.default_json_options
      opts[:only] ||= []
      opts[:only] << :description if @selected_user.known_non_spammer?
      format.json { render :json => @selected_user.to_json( opts ) }
    end
  end

  def followers
    @users = @user.followers
    @users = @users.page( params[:page] ).order( :login )
    counts_for_users
    respond_to do |format|
      format.html { render :friendship_users, layout: "bootstrap" }
    end
  end

  def following
    @users = @user.followees
    @users = @users.page( params[:page] ).order( :login )
    counts_for_users
    respond_to do |format|
      format.html { render :friendship_users, layout: "bootstrap" }
    end
  end
  
  def relationships
    @friendships = current_user.friendships.page( params[:page] )
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
    else
      # have latitude and longitude so show local content
      # use place_id to fetch content from country or state
      if current_user.lat_lon_acc_admin_level == 0 || current_user.lat_lon_acc_admin_level == Place::STATE_LEVEL
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
    if params[:from]
      filters << { range: { created_at: { lt: Time.at( params[:from].to_i ) } } }
    end
    unless params[:notifier_type].blank?
      filters << { term: { notifier_type: params[:notifier_type] } }
    end
    if params[:filter] == "you"
      filters << { term: { resource_owner_id: current_user.id } }
      @you = true
    end
    if params[:filter] == "following"
      filters << { terms: { notification: %w(created_observations new_observations) } }
    end
    
    @pagination_updates = current_user.recent_notifications(
      filters: filters, per_page: 50)
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
    if @site && !@site.discourse_url.blank? && @discourse_url = @site.discourse_url
      cache_key = "dashboard-discourse-data-#{@site.id}"
      begin
        if @site.discourse_category.blank?
          url = "#{@discourse_url}/latest.json?order=created"
          @discourse_topics_url = @discourse_url
        else
          url = "#{@discourse_url}/c/#{@site.discourse_category}.json?order=created"
          @discourse_topics_url = "#{@discourse_url}/c/#{@site.discourse_category}"
        end
        unless @discourse_data = Rails.cache.read( cache_key )
          @discourse_data = {}
          @discourse_data[:categories] = JSON.parse(
            RestClient::Request.execute( method: "get",
              url: "#{@discourse_url}/categories.json", open_timeout: 1, timeout: 5 ).body
          )["category_list"]["categories"].index_by{|c| c["id"]}
          discourse_ignored_category_names = [
            "Forum Feedback",
            "Nature Talk"
          ]
          discourse_ignored_category_ids = @discourse_data[:categories].values.select do |c|
            discourse_ignored_category_names.include?( c["name"] )
          end.map{ |c| c["id"] }
          @discourse_data[:topics] = JSON.parse(
            RestClient::Request.execute(
              method: "get",
              url: url,
              open_timeout: 1,
              timeout: 5
            ).body
          )["topic_list"]["topics"].select{ | t |
            !t["pinned"] &&
            !t["closed"] &&
            !t["has_accepted_answer"] &&
            # Remove posts in the Forum Feedback category
            (
              !t["category_id"] ||
              !discourse_ignored_category_ids.include?( t["category_id"] )
            )
          }[0..5]
          Rails.cache.write( cache_key, @discourse_data, expires_in: 15.minutes )
        end
      rescue SocketError, RestClient::Exception, Timeout::Error, RestClient::Exceptions::Timeout
        @discourse_data = nil
        # No connection or other connection issue
        nil
      end
    end
    respond_to do |format|
      format.html do
        @announcements = [
          Announcement.active_in_placement( "users/dashboard", @site),
          Announcement.active_in_placement( "users/dashboard#sidebar", @site )
        ].flatten.compact
        @subscriptions = current_user.subscriptions.includes(:resource).
          where("resource_type in ('Place', 'Taxon')").
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
      filters: [ { terms: { notification: [ "activity", "mention" ] } } ], per_page: 1).total_entries
    session[:updates_count] = count
    render :json => {:count => count}
  end
  
  def new_updates
    # not sure why current_user would be nil here, but sometimes it is
    return redirect_to login_path if !current_user
    params[:notification] ||= "activity"
    params[:notification] = params[:notification].split(",")
    filters = [ { terms: { notification: params[:notification] } } ]
    notifier_types = [(params[:notifier_types] || params[:notifier_type])].compact
    unless notifier_types.blank?
      notifier_types = notifier_types.map{|t| t.split(',')}.flatten.compact.uniq
      filters << { terms: { notifier_type: notifier_types.map(&:capitalize) } }
    end
    unless params[:resource_type].blank?
      filters << { term: { resource_type: params[:resource_type].capitalize } }
    end
    @updates = current_user.recent_notifications(unviewed: true, per_page: 200, filters: filters)
    unless request.format.json?
      if @updates.count == 0
        @updates = current_user.recent_notifications(viewed: true, per_page: 10, filters: filters)
      end
      if @updates.count == 0
        @updates = current_user.recent_notifications(per_page: 5, filters: filters)
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
      format.html do
        @monthly_supporter = @user.donorbox_plan_status == "active" && @user.donorbox_plan_type == "monthly"
        render :edit2, layout: "bootstrap"
      end
      format.json do
        render :json => @user.to_json(
          :except => [
            :crypted_password, :salt, :old_preferences, :activation_code,
            :remember_token, :last_ip, :suspended_at, :suspension_reason,
            :icon_content_type, :icon_file_name, :icon_file_size,
            :icon_updated_at, :deleted_at, :remember_token_expires_at,
            :icon_url, :latitude, :longitude, :lat_lon_acc_admin_level
          ],
          :methods => [
            :user_icon_url, :medium_user_icon_url, :original_user_icon_url,
            :prefers_no_tracking
          ]
        )
      end
    end
  end

  # this is the page that's shown after a new user is created via 3rd party provider_authorization
  # allows user to pick a new username if he doesn't like the one we autogenerated.
  def edit_after_auth
    redirect_to "/" and return unless (flash[:allow_edit_after_auth] || params[:test])
    load_registration_form_data
    respond_to do |format|
      format.html do
        render layout: "registrations"
      end
    end
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

    @display_user.assign_attributes( permit_params ) unless permit_params.blank?
    place_id_changed = @display_user.will_save_change_to_place_id?
    prefers_no_place_changed = @display_user.prefers_no_place_changed?
    prefers_no_site_changed = @display_user.prefers_no_site_changed?
    if @display_user.save
      # user changed their project addition rules and nothing else, so
      # updated_at wasn't touched on user. Set set updated_at on the user
      if @display_user.preferred_project_addition_by != preferred_project_addition_by_was &&
         @display_user.previous_changes.empty?
        @display_user.update_columns(updated_at: Time.now)
      end
      bypass_sign_in( @display_user )
      respond_to do |format|
        format.html do
          if locale_was != @display_user.locale
            session[:locale] = @display_user.locale
          end

          if place_id_changed
            session.delete(:potential_place)
            if params[:from_potential_place]
              flash[:notice] = I18n.t( "views.users.edit.place_preference_changed_notice_html" )
            end
          elsif prefers_no_place_changed
            session.delete(:potential_place)
            if params[:from_potential_place]
              flash[:notice] = I18n.t( "views.users.edit.if_you_change_your_mind_you_can_always_edit_your_settings_html" )
            end
          end

          if prefers_no_site_changed
            session.delete(:potential_site)
            if params[:from_potential_site]
              flash[:notice] = I18n.t( "views.users.edit.if_you_change_your_mind_you_can_always_edit_your_settings_html" )
            end
          end

          if params[:from_edit_after_auth].blank?
            flash[:notice] ||= t(:your_profile_was_successfully_updated)
            redirect_back_or_default(person_by_login_path(:login => current_user.login))
          else
            redirect_to(dashboard_path)
          end
        end
        format.json do
          User.refresh_es_index
          render :json => @display_user.to_json(User.default_json_options)
        end
      end
    else
      @display_user.login = @display_user.login_was unless @display_user.errors[:login].blank?
      respond_to do |format|
        format.html do
          before_edit
          if request.env['HTTP_REFERER'] =~ /edit_after_auth/ || params[:from_edit_after_auth]
            load_registration_form_data
            render "users/registrations/new", layout: "bootstrap"
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
      @display_user ||= User.find_by_email(params[:id]) unless params[:id].blank?
      @display_user ||= User.where( "email ILIKE ?", "%#{params[:id]}%" ).first
      @display_user ||= User.elastic_paginate( query: {
        bool: {
          should: [
            { match: { name: { query: params[:id], operator: "and" } } },
            { match: { login: { query: params[:id], operator: "and" } } }
          ]
        }
      } ).first
      if @display_user.blank?
        flash[:error] = t(:couldnt_find_a_user_matching_x_param, :id => params[:id])
      else
        @observations = Observation.page_of_results( user_id: @display_user.id )
      end
    end
    respond_to do |format|
      format.html { render layout: "bootstrap" }
    end
  end

  def recent
    @users = User.order( "id desc" ).page( 1 ).per_page( 10 )
    @spammer = params[:spammer]
    if @spammer.nil? || @spammer == "unknown"
      @users = @users.where( "spammer IS NULL" )
    elsif @spammer.yesish?
      @users = @users.where( "spammer" )
      if params[:flagged_by] == "auto"
        @users = @users.joins(:flags).where( "NOT resolved AND flag = 'spam'" ).where( "flags.user_id = 0" )
      elsif params[:flagged_by] == "manual"
        @users = @users.joins(:flags).where( "NOT flags.resolved AND flag = 'spam'" ).where( "flags.user_id > 0" )
      end
    elsif @spammer.noish?
      @users = @users.where( "NOT spammer" )
    end
    if params[:obs].yesish?
      @users = @users.where( "observations_count > 0" )
    elsif params[:obs].noish?
      @users = @users.where( "observations_count = 0" )
    end
    if params[:ids].yesish?
      @users = @users.where( "identifications_count > 0" )
    elsif params[:ids].noish?
      @users = @users.where( "identifications_count = 0" )
    end
    if params[:description].yesish?
      @users = @users.where( "description IS NOT NULL AND description != ''" )
    elsif params[:description].noish?
      @users = @users.where( "description IS NULL OR description = ''" )
    end
    if params[:from].to_i > 0
      @users = @users.where( "users.id < ?", params[:from].to_i )
    end
    if params[:chart]
      start_date = 3.months.ago.to_date
      total_new_user_counts = User.where( "created_at > ?", start_date ).group( "created_at::date" ).count
      new_automated_spam_flag_counts = Flag.
        where( "u.created_at > ? AND flaggable_type = 'User' AND flag = 'spam' AND NOT resolved AND user_id = 0", start_date ).
        joins( "JOIN users u ON u.id = flags.flaggable_id" ).
        group( "u.created_at::date" ).count
      new_manual_spam_flag_counts = Flag.
        where( "u.created_at > ? AND flaggable_type = 'User' AND flag = 'spam' AND NOT resolved AND user_id > 0", start_date ).
        joins( "JOIN users u ON u.id = flags.flaggable_id" ).
        group( "u.created_at::date" ).count
      probable_spam_user_counts = User.
        where( "spammer IS NULL" ).
        where( "observations_count = 0 AND identifications_count = 0" ).
        where( "description IS NOT NULL AND description != ''" ).
        where( "created_at > ?", start_date ).group( "created_at::date" ).count
      false_positive_counts = Flag.
        where( "u.created_at > ? AND flaggable_type = 'User' AND flag = 'spam' AND resolved", start_date ).
        joins( "JOIN users u ON u.id = flags.flaggable_id" ).
        group( "u.created_at::date" ).count
      @stats = ( start_date...Date.tomorrow ).map do |d|
        {
          date: d.to_s,
          new_users: total_new_user_counts[d],
          auto_spam: new_automated_spam_flag_counts[d],
          manual_spam: new_manual_spam_flag_counts[d],
          probable_spam: probable_spam_user_counts[d],
          false_positives: false_positive_counts[d]
        }
      end
    end
    respond_to do |format|
      format.html { render layout: "bootstrap" }
    end
  end

  def merge
    unless @reject_user = User.find_by_id( params[:reject_user_id] )
      flash[:error] = "Couldn't find user to delete"
      redirect_back_or_default "/"
    end
    @user.merge( @reject_user )
    flash[:notice] = "Merged user #{@reject_user.login} deleted"
    redirect_back_or_default "/"
  end

  def update_session
    allowed_patterns = [
      /^show_quality_metrics$/,
      /^user-seen-ann*/,
      /^prefers_*/,
      /^preferred_*/,
      /^header_search_open$/
    ]
    updates = params.to_unsafe_h.select {|k,v|
      allowed_patterns.detect{|p| 
        k.match(p)
      }
    }.symbolize_keys
    updates.each do |k,v|
      v = true if v.yesish? && v != "1"
      v = false if v.noish?
      session[k] = v
      if (k =~ /^prefers_/ || k =~ /^preferred_/) && logged_in? && current_user.respond_to?(k)
        current_user.update(k => v)
      end
    end
    head :no_content
  end

  def api_token
    # not sure why current_user would be nil here, but sometimes it is
    return redirect_to login_path if !current_user
    payload = { user_id: current_user.id }
    if doorkeeper_token && (a = doorkeeper_token.application)
      payload[:oauth_application_id] = a.becomes( OauthApplication ).id
    end
    render json: { api_token: JsonWebToken.encode( payload ) }
  end

  def join_test
    groups = current_user.test_groups_array
    if params[:leave]
      groups -= [params[:leave]].flatten
    end
    groups = ( groups + [params[:test]] ).compact.uniq
    current_user.update( test_groups: groups.join( "|" ) )
    redirect_back_or_default( root_path )
  end

  def leave_test
    groups = ( current_user.test_groups_array - [params[:test]].flatten ).compact.uniq
    current_user.update( test_groups: groups.join( "|" ) )
    redirect_back_or_default( root_path )
  end

  def trust
    if friendship = current_user.friendships.where( friend_id: params[:id] ).first
      friendship.update( trust: true )
    else
      friendship = current_user.friendships.create!( friend: @user, trust: true, following: false )
    end
    respond_to do |format|
      format.json { render json: { friendship: friendship } }
    end
  end

  def untrust
    if friendship = current_user.friendships.where( friend_id: params[:id] ).first
      friendship.update( trust: false )
    end
    respond_to do |format|
      format.json { render json: { friendship: friendship } }
    end
  end

  def parental_consent
    error_msg = nil
    if !params[:email]
      error_msg = :must_specify_email
    elsif params[:email] !~ Devise.email_regexp
      error_msg = :invalid_email
    end
    if error_msg
      respond_to do |format|
        format.json { render status: :unprocessable_entity, json: { error: t( "parental_consent.#{error_msg}" ) } }
      end
      return
    end
    unless current_user && current_user.id == Devise::Strategies::ApplicationJsonWebToken::ANONYMOUS_USER_ID
      respond_to do |format|
        format.json { render status: :forbidden, json: { error: "forbidden" } }
      end
      return
    end
    Emailer.parental_consent( params[:email] ).deliver_now
    respond_to do |format|
      format.json { head :no_content }
    end
  end

  def mute
    @user_mute = current_user.user_mutes.where( muted_user_id: @user ).first
    @user_mute ||= current_user.user_mutes.create( muted_user: @user )
    respond_to do |format|
      format.json do
        if @user_mute.valid?
          head :no_content
        else
          render status: :unprocessable_entity, json: { errors: @user_mute.errors }
        end
      end
    end
  end

  def unmute
    @user_mute = current_user.user_mutes.where( muted_user_id: @user ).first
    @user_mute.destroy if @user_mute
    respond_to do |format|
      format.json do
        if @user_mute
          head :no_content
        else
          render status: :unprocessable_entity, json: { errors: ["User #{@user.id} was not muted"] }
        end
      end
    end
  end

  def block
    @user_block = current_user.user_blocks.where( blocked_user_id: @user ).first
    @user_block ||= current_user.user_blocks.create( blocked_user: @user )
    respond_to do |format|
      format.json do
        if @user_block.valid?
          head :no_content
        else
          render status: :unprocessable_entity, json: { errors: @user_block.errors }
        end
      end
    end
  end

  def unblock
    @user_block = current_user.user_blocks.where( blocked_user_id: @user ).first
    @user_block.destroy if @user_block
    respond_to do |format|
      format.json do
        if @user_block
          head :no_content
        else
          render status: :unprocessable_entity, json: { errors: ["User #{@user.id} was not blocked"] }
        end
      end
    end
  end

  def moderation
    before = params[:before] || Time.now
    if @user == current_user && !current_user.is_admin?
      flash[:error] = t(:you_dont_have_permission_to_do_that)
      return redirect_back_or_default person_by_login_path( @user.login )
    end
    max = 100
    @valid_years = ( 2008..Date.today.year ).to_a.reverse
    @years = ( params[:years] || [] ).map(&:to_i) & @valid_years
    @types = ( params[:types] || [] ) & %w(Flag ModeratorNote ModeratorAction)
    scopes = {}
    scopes["ModeratorNote"] = ModeratorNote.
      where( subject_user_id: @user ).
      where( "created_at < ?", before ).
      order( "id desc" )
    scopes["Flag"] = Flag.
      where( "created_at < ?", before ).
      where( flaggable_user_id: @user ).
      where( "flaggable_type != 'Taxon'" ).
      order( "id desc" )
    @records = []
    scopes.each do |type, scope|
      next unless @types.blank? || @types.include?( type )
      if @years.blank?
        scope = scope.limit( max )
      else
        @years.each do |year|
          d1 = "#{year}-01-01"
          d2 = "#{year}-12-31"
          scope = scope.where( "#{Object.const_get( type ).table_name}.created_at BETWEEN ? AND ?", d1, d2 )
        end
      end
      @records += scope.to_a
    end
    if @types.blank? || @types.include?( "ModeratorAction" )
      ma_scope = ModeratorAction.
        where( "moderator_actions.created_at < ?", before ).
        order( "moderator_actions.id desc" )
      if @years.blank?
        ma_scope = ma_scope.limit( max )
      else
        @years.each do |year|
          ma_scope = ma_scope.where(
            "moderator_actions.created_at BETWEEN ? AND ?",
            "#{year}-01-01",
            "#{year}-12-31"
          )
        end
      end
      @records += ma_scope.
        where( resource_type: "Identification" ).
        joins( "JOIN identifications i ON i.id = moderator_actions.resource_id" ).
        where( "i.user_id = ?", @user ).to_a
      @records += ma_scope.
        where( resource_type: "Comment" ).
        joins( "JOIN comments c ON c.id = moderator_actions.resource_id" ).
        where( "c.user_id = ?", @user ).to_a
      @records += ma_scope.
        where( resource_type: "User" ).
        where( "moderator_actions.resource_id = ?", @user ).to_a
    end
    @records = @records.flatten.sort_by {|r| r.created_at }
    respond_to do |format|
      format.html do
        render layout: "bootstrap-container"
      end
    end
  end

protected

  def add_friend
    error_msg, notice_msg = [nil, nil]
    friend_user = User.find_by_id(params[:friend_id])
    if friend_user.blank? || friendship = current_user.friendships.where( friend_id: friend_user.id, following: true ).first
      error_msg = t(:either_that_user_doesnt_exist_or)
    else
      notice_msg = t(:you_are_now_following_x, :friend_user => friend_user.login)
      if friendship = current_user.friendships.where( friend_id: friend_user.id ).first
        friendship.update( following: true )
      else
        friendship = current_user.friendships.create( friend: friend_user, following: true )
      end
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
      if friendship.trust?
        friendship.update( following: false )
      else
        friendship.destroy
      end
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
      @user ||= User.where( uuid: params[:id] ).first
      render_404 if @user.blank?
    end
  end
  
  def ensure_user_is_current_user_or_admin
    if !current_user.has_role?( :admin ) && @user.id != current_user.id
      respond_to do |format|
        format.html do
          redirect_to edit_user_path(current_user, :id => current_user.login)
        end
        format.json do
          render status: :unprocessable_entity, json: { error: t(:you_dont_have_permission_to_do_that) }
        end
      end
    end
  end
  
  def counts_for_users
    @species_counts = @users.map{ |i| [i.id, i.species_count] }.to_h
    @post_counts = Post.where(user_id: @users.to_a, parent_type: "User").group(:user_id).count
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
    elastic_params[:verifiable] = true
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
    elastic_params[:verifiable] = true
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
    filters = [
      { term: { own_observation: false } }
      # Uncomment if / when we want to only show ident stats from verifiable obs
      # {
      #   terms: {
      #     "observation.quality_grade": [Observation::RESEARCH_GRADE, Observation::NEEDS_ID]
      #   }
      # }
    ]
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

    # This is brittle and will continue to cause problems for individual sites
    # as we grow and their top users fall out of the global top 500.
    result = Identification.elastic_search(
      filters: filters,
      size: 0,
      aggregate: {
        obs: {
          terms: { field: "user.id", size: site_filter ? 500 : 20 }
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

  def permit_params
    return if params[:user].blank?
    params.require(:user).permit(
      :data_transfer_consent,
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
      :pi_consent,
      :place_id,
      :preferred_identify_image_size,
      :preferred_observation_fields_by,
      :preferred_observation_license,
      :preferred_observations_search_map_type,
      :preferred_observations_view,
      :preferred_photo_license,
      :preferred_project_addition_by,
      :preferred_sound_license,
      :prefers_captive_obs_maps,
      :prefers_comment_email_notification,
      :prefers_forum_topics_on_dashboard,
      :prefers_identification_email_notification,
      :prefers_identify_side_bar,
      :prefers_message_email_notification,
      :prefers_medialess_obs_maps,
      :prefers_project_invitation_email_notification,
      :prefers_mention_email_notification,
      :prefers_project_journal_post_email_notification,
      :prefers_project_curator_change_email_notification,
      :prefers_project_added_your_observation_email_notification,
      :prefers_taxon_change_email_notification,
      :prefers_user_observation_email_notification,
      :prefers_taxon_or_place_observation_email_notification,
      :prefers_no_email,
      :prefers_automatic_taxonomic_changes,
      :prefers_community_taxa,
      :prefers_location_details,
      :prefers_receive_mentions,
      :prefers_redundant_identification_notifications,
      :prefers_common_names,
      :prefers_scientific_name_first,
      :prefers_no_place,
      :prefers_no_site,
      :prefers_no_tracking,
      :prefers_monthly_supporter_badge,
      :search_place_id,
      :site_id,
      :test_groups,
      :time_zone
    )
  end

  def before_edit
    @sites = Site.live.limit(100)
    if @user = current_user
      @user.site_id ||= Site.first.try(:id) unless @sites.blank?
    end
  end

  def site_admin_of_user_required
    unless logged_in? && @user && current_user.is_site_admin_of?( @user.site )
      flash[:notice] = t(:only_administrators_may_access_that_page)
      if session[:return_to] == request.fullpath
        redirect_to root_url
      else
        redirect_back_or_default(root_url)
      end
      return false
    end
  end

end
