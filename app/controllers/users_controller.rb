class UsersController < ApplicationController  
  doorkeeper_for :create, :update, :edit, :dashboard, :if => lambda { authenticate_with_oauth? }
  before_filter :authenticate_user!, 
    :unless => lambda { authenticated_with_oauth? },
    :except => [:index, :show, :new, :create, :activate, :relationships]
  before_filter :find_user, :only => [:suspend, :unsuspend, :destroy, :purge, 
    :show, :update, :relationships, :add_role, :remove_role]
  before_filter :ensure_user_is_current_user_or_admin, :only => [:update, :destroy]
  before_filter :admin_required, :only => [:curation]
  before_filter :curator_required, :only => [:suspend, :unsuspend]
  before_filter :return_here, :only => [:index, :show, :relationships, :dashboard, :curation]
  
  MOBILIZED = [:show, :dashboard, :new, :create]
  before_filter :unmobilized, :except => MOBILIZED
  before_filter :mobilized, :only => MOBILIZED
  
  caches_action :dashboard,
    :expires_in => 1.hour,
    :cache_path => Proc.new {|c| c.send(:home_url, :user_id => c.instance_variable_get("@current_user").id)},
    :if => Proc.new {|c| (c.params.keys - %w(action controller)).blank? }
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
      @user.update_attribute(:last_ip, request.env['REMOTE_ADDR'])
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
    @user.delay(:priority => USER_PRIORITY).sane_destroy
    sign_out(@user)
    flash[:notice] = "#{@user.login} has been removed from #{CONFIG.site_name} " + 
      "(it may take up to an hour to completely delete all associated content)"
    redirect_to root_path
  end
  
  # Methods below here are added by iNaturalist
  
  def index
    @recently_active_key = "recently_active_#{I18n.locale}_#{SITE_NAME}"
    unless fragment_exist?(@recently_active_key)
      @updates = []
      [Observation, Identification, Post, Comment].each do |klass|
        scope = klass.limit(30).
          order("#{klass.table_name}.id DESC").
          where("#{klass.table_name}.created_at > ?", 1.week.ago).
          where("users.id IS NOT NULL").
          includes(:user)
        scope = scope.where("users.uri LIKE ?", "#{CONFIG.site_url}%") if CONFIG.site_only_users
        @updates += scope.all
      end
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
      @curators = User.curators.limit(500)
      @curators = @curators.where("users.uri LIKE ?", "#{CONFIG.site_url}%") if CONFIG.site_only_users
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
    @month = (params[:month] || Time.now.month).to_i
    @date = Date.parse("#{@year}-#{@month}-01")
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
    scope = User.active.order('login').scoped
    @q = params[:q].to_s
    if logged_in? && !@q.blank?
      wildcard_q = @q.size == 1 ? "#{@q}%" : "%#{@q.downcase}%"
      conditions = if @q =~ Devise.email_regexp
        ["email = ?", @q]
      elsif @q =~ /\w+\s+\w+/
        ["lower(name) LIKE ?", wildcard_q]
      else
        ["lower(login) LIKE ? OR lower(name) LIKE ?", wildcard_q, wildcard_q]
      end
      scope = scope.where(conditions)
    end
    @users = scope.page(params[:page])
    respond_to do |format|
      format.html { counts_for_users }
      format.json do
        haml_pretty do
          @users.each_with_index do |user, i|
            @users[i].html = view_context.render_in_format(:html, :partial => "users/chooser", :object => user).gsub(/\n/, '')
          end
        end
        render :json => @users.to_json(User.default_json_options.merge(:methods => [:html]))
      end
    end
  end
  
  def show
    @selected_user = @user
    @login = @selected_user.login
    @followees = @selected_user.friends.paginate(:page => 1, :per_page => 15, :order => "id desc")
    @favorites_list = @selected_user.lists.find_by_title("Favorites")
    @favorites_list ||= @selected_user.lists.find_by_title(t(:favorites))
    if @favorites_list
      @favorite_listed_taxa = @favorites_list.listed_taxa.paginate(:page => 1, 
        :per_page => 15,
        :include => {:taxon => [:photos, :taxon_names]}, :order => "listed_taxa.id desc")
    end
    
    respond_to do |format|
      format.html
      format.json { render :json => @selected_user.to_json(User.default_json_options) }
      format.mobile
    end
  end
  
  def relationships
    find_options = {:page => params[:page] || 1, :order => 'login'}
    @users = if params[:following]
      User.find_by_login(params[:login]).friends.paginate(find_options)
    else
      User.find_by_login(params[:login]).followers.paginate(find_options)
    end
    counts_for_users
  end
  
  def dashboard
    conditions = ["id < ?", params[:from].to_i] if params[:from]
    updates = current_user.updates.all(:limit => 50, :order => "id DESC", 
      :include => [:resource, :notifier, :subscriber, :resource_owner],
      :conditions => conditions)
    @updates = Update.load_additional_activity_updates(updates)
    @update_cache = Update.eager_load_associates(@updates)
    @grouped_updates = Update.group_and_sort(@updates, :update_cache => @update_cache, :hour_groups => true)
    Update.user_viewed_updates(updates)
    @month_observations = current_user.observations.all(:select => "id, observed_on",
      :conditions => [
        "EXTRACT(month FROM observed_on) = ? AND EXTRACT(year FROM observed_on) = ?",
        Date.today.month, Date.today.year
        ])
    respond_to do |format|
      format.html do
        @subscriptions = current_user.subscriptions.includes(:resource).
          where("resource_type in ('Place', 'Taxon')").
          order("subscriptions.id DESC").
          limit(5)
        if current_user.is_curator? || current_user.is_admin?
          @flags = Flag.order("id desc").where("resolved = ?", false).limit(5)
          @ungrafted_taxa = Taxon.order("id desc").where("ancestry IS NULL").limit(5).active
        end
      end
      format.mobile
    end
  end
  
  def updates_count
    count = current_user.updates.unviewed.activity.count
    session[:updates_count] = count
    render :json => {:count => count}
  end
  
  def new_updates
    @updates = current_user.updates.unviewed.activity.all(
      :include => [:resource, :notifier, :subscriber, :resource_owner],
      :order => "id DESC",
      :limit => 200
    )
    session[:updates_count] = 0
    if @updates.blank?
      @updates = current_user.updates.activity.all(
        :include => [:resource, :notifier, :subscriber, :resource_owner],
        :order => "id DESC",
        :limit => 10,
        :conditions => ["viewed_at > ?", 1.day.ago])
    end
    if @updates.blank?
      @updates = current_user.updates.activity.all(:limit => 5, :order => "id DESC")
    else
      Update.user_viewed_updates(@updates)
    end
    @update_cache = Update.eager_load_associates(@updates)
    @updates = @updates.sort_by{|u| u.created_at.to_i * -1}
    render :layout => false
  end
  
  def edit
    @user = current_user
    respond_to do |format|
      format.html
      format.json do
        render :json => @user.to_json(
          :except => [
            :crypted_password, :salt, :old_preferences, :activation_code,
            :remember_token, :last_ip, :suspended_at, :suspension_reason,
            :icon_content_type, :icon_file_name, :icon_file_size,
            :icon_updated_at, :deleted_at, :remember_token_expires_at, :icon_url
          ],
          :methods => [:user_icon_url]
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
    
    params[:user].each do |k,v|
      if k =~ /^prefer/
        params[:user].delete(k)
      else
        next
      end
      @display_user.send("#{k}=", v)
    end
    
    # Nix the icon_url if an icon file was provided
    @display_user.icon_url = nil if params[:user].try(:[], :icon)
    
    if @display_user.update_attributes(params[:user])
      sign_in @display_user, :bypass => true
      respond_to do |format|
        format.html do
          flash[:notice] = t(:your_profile_was_successfully_updated)
          redirect_back_or_default(person_by_login_path(:login => current_user.login))
        end
        format.json do
          render :json => @display_user.to_json(User.default_json_options)
        end
      end
    else
      @display_user.login = @display_user.login_was unless @display_user.errors[:login].blank?
      respond_to do |format|
        format.html do
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
      @users = User.paginate(:page => params[:page], :order => "id desc")
      @comment_counts_by_user_id = Comment.count(:group => :user_id, :conditions => ["user_id IN (?)", @users])
    else
      @display_user = User.find_by_id(params[:id].to_i)
      @display_user ||= User.find_by_login(params[:id])
      @display_user ||= User.find_by_email(params[:id])
      if @display_user.blank?
        flash[:error] = t(:couldnt_find_a_user_matching_x_param, :id => params[:id])
      else
        @observations = @display_user.observations.order("id desc").limit(10)
      end
    end
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
    @observation_counts = Observation.count(:conditions => ["user_id IN (?)", @users], :group => :user_id)
    @listed_taxa_counts = ListedTaxon.count(:conditions => ["list_id IN (?)", @users.map{|u| u.life_list_id}], 
      :group => :user_id)
    @post_counts = Post.count(:conditions => ["user_id IN (?)", @users], :group => :user_id)
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
    scope = Observation.group(:user_id).
      where("EXTRACT(YEAR FROM observed_on) = ?", year).scoped
    if per == 'month'
      scope = scope.where("EXTRACT(MONTH FROM observed_on) = ?", month)
    end
    scope = scope.where("observations.uri LIKE ?", "#{CONFIG.site_url}%") if CONFIG.site_only_users
    counts = scope.count.to_a.sort_by(&:last).reverse[0..4]
    users = User.where("id IN (?)", counts.map(&:first))
    counts.inject({}) do |memo, item|
      memo[users.detect{|u| u.id == item.first}] = item.last
      memo
    end
  end

  def most_species(options = {})
    per = options[:per] || 'month'
    year = options[:year] || Time.now.year
    month = options[:month] || Time.now.month
    date_clause = "EXTRACT(YEAR FROM o.observed_on) = #{year}"
    date_clause += "AND EXTRACT(MONTH FROM o.observed_on) = #{month}" if per == 'month'
    site_clause = if CONFIG.site_only_users
      "AND o.uri LIKE '#{CONFIG.site_url}%'"
    end
    sql = <<-SQL
      SELECT
        o.user_id,
        count(*) AS count_all
      FROM
        (
          SELECT DISTINCT o.taxon_id, o.user_id
          FROM
            observations o
              JOIN taxa t ON o.taxon_id = t.id
          WHERE
            t.rank_level <= 10 AND
              #{date_clause}
              #{site_clause}
        ) as o
      GROUP BY o.user_id
      ORDER BY count_all desc
      LIMIT 5
    SQL
    rows = ActiveRecord::Base.connection.execute(sql)
    users = User.where("id IN (?)", rows.map{|r| r['user_id']})
    rows.inject([]) do |memo, row|
      memo << [users.detect{|u| u.id == row['user_id'].to_i}, row['count_all']]
      memo
    end
  end

  def most_identifications(options = {})
    per = options[:per] || 'month'
    year = options[:year] || Time.now.year
    month = options[:month] || Time.now.month
    scope = Identification.group("identifications.user_id").
      joins(:observation, :user).
      where("identifications.user_id != observations.user_id").
      where("EXTRACT(YEAR FROM identifications.created_at) = ?", year).
      order('count_all desc').
      limit(5).scoped
    if per == 'month'
      scope = scope.where("EXTRACT(MONTH FROM identifications.created_at) = ?", month)
    end
    scope = scope.where("users.uri LIKE ?", "#{CONFIG.site_url}%") if CONFIG.site_only_users
    counts = scope.count.to_a
    users = User.where("id IN (?)", counts.map(&:first))
    counts.inject({}) do |memo, item|
      memo[users.detect{|u| u.id == item.first}] = item.last
      memo
    end
  end
    
end
