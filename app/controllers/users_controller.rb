class UsersController < ApplicationController  
  before_filter :authenticate_user!, :except => [:index, :show, :new, :create, :activate, :relationships]
  before_filter :find_user, :only => [:suspend, :unsuspend, :destroy, :purge, 
    :show, :edit, :update, :relationships, :add_role, :remove_role]
  before_filter :ensure_user_is_current_user_or_admin, :only => [:edit, :update, :destroy]
  before_filter :admin_required, :only => [:suspend, :unsuspend, :curation]
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
      flash[:notice] = "Welcome to iNaturalist!  Please check for your confirmation email, but feel free to start cruising the site."
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

  def activate
    logout_keeping_session! unless logged_in? && current_user.is_admin?
    user = User.find_by_activation_code(params[:activation_code]) unless params[:activation_code].blank?
    case
    when (!params[:activation_code].blank?) && user && !user.active?
      user.activate!
      flash[:notice] = "Your #{APP_CONFIG[:site_name]} account has been verified! Please sign in to continue."
      if logged_in? && current_user.is_admin?
        redirect_back_or_default('/')
      else
        redirect_to '/login'
      end
    when params[:activation_code].blank?
      flash[:error] = "Your activation code was missing.  Please follow the URL from your email."
      redirect_back_or_default('/')
    else 
      flash[:error]  = "We couldn't find a user with that activation code. You may have already activated your account, please try signing in."
      redirect_back_or_default('/')
    end
  end

  # Don't take these out yet, useful for admin user management down the road

  def suspend
     @user.suspend! 
     flash[:notice] = "The user #{@user.login} has been suspended"
     redirect_to users_path
  end
   
  def unsuspend
    @user.unsuspend! 
    flash[:notice] = "The user #{@user.login} has been unsuspended"
    redirect_to users_path
  end
  
  def add_role
    unless @role = Role.find_by_name(params[:role])
      flash[:error] = "That role doesn't exist"
      return redirect_to :back
    end
    
    if !current_user.has_role?(@role.name) || (@user.is_admin? && !current_user.is_admin?)
      flash[:error] = "Sorry, you don't have permission to do that"
      return redirect_to :back
    end
    
    @user.roles << @role
    flash[:notice] = "Made #{@user.login} a(n) #{@role.name}"
    redirect_to :back
  end
  
  def remove_role
    unless @role = Role.find_by_name(params[:role])
      flash[:error] = "That role doesn't exist"
      return redirect_to :back
    end
    
    unless current_user.has_role?(@role.name)
      flash[:error] = "Sorry, you don't have permission to do that"
      return redirect_to :back
    end
    
    if @user.roles.delete(@role)
      flash[:notice] = "Removed #{@role.name} status from #{@user.login}"
    else
      flash[:error] = "#{@user.login} doesn't have #{@role.name} status"
    end
    redirect_to :back
  end
  
  # There's no page here to update or destroy a user.  If you add those, be
  # smart -- make sure you check that the visitor is authorized to do so, that they
  # supply their old password along with a new one to update it, etc.
  
  def destroy
    unless @user.project_users.blank? #remove any curator id's this user might have made
      @user.project_users.each do |pu|
        unless pu.role.nil?
          Project.delay.update_curator_idents_on_remove_curator(pu.project_id, @user.id)
        end
      end
    end
    @user.destroy
    flash[:notice] = "#{@user.login} removed from iNaturalist"
    redirect_to users_path
  end
  
  # Methods below here are added by iNaturalist
  
  def index
    unless fragment_exist?("recently_active")
      update_find_options = {
        :limit => 10, 
        :order => "id DESC",
        :conditions => ["created_at > ?", 1.week.ago],
        :include => :user
      }
      @updates = [
        Observation.all(update_find_options),
        Identification.all(update_find_options),
        Post.published.all(update_find_options),
        Comment.all(update_find_options)
      ].flatten.sort{|a,b| b.created_at <=> a.created_at}.group_by(&:user)
    end

    find_options = {
      :page => params[:page] || 1, :order => 'login'
    }
    @q = params[:q].to_s
    if logged_in? && !@q.blank?
      wildcard_q = @q.size == 1 ? "#{@q}%" : "%#{@q.downcase}%"
      if @q =~ Devise.email_regexp
        find_options[:conditions] = ["email = ?", @q]
      elsif @q =~ /\w+\s+\w+/
        find_options[:conditions] = ["lower(name) LIKE ?", wildcard_q]
      else
        find_options[:conditions] = ["lower(login) LIKE ? OR lower(name) LIKE ?", wildcard_q, wildcard_q]
      end
    end
    @alphabet = %w"a b c d e f g h i j k l m n o p q r s t u v w x y z"
    if (@letter = params[:letter]) && @alphabet.include?(@letter.downcase)
      find_options.update(:conditions => ["login LIKE ?", "#{params[:letter].first}%"])
    end
    @users = User.active.paginate(find_options)
    counts_for_users
  end
  
  def show
    @selected_user = @user
    @login = @selected_user.login
    @followees = @selected_user.friends.paginate(:page => 1, :per_page => 15, :order => "id desc")
    if @favorites_list = @selected_user.lists.find_by_title("Favorites")
      @favorite_listed_taxa = @favorites_list.listed_taxa.paginate(:page => 1, 
        :per_page => 15,
        :include => {:taxon => [:photos, :taxon_names]}, :order => "listed_taxa.id desc")
    end
    
    respond_to do |format|
      format.html
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
      format.html
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
    respond_to do |format|
      format.html
      format.json { render :json => @user.to_json(:except => [
        :crypted_password, :salt, :old_preferences, :activation_code, 
        :remember_token, :last_ip]) }
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
      flash[:notice] = 'Your profile was successfully updated!'
      redirect_back_or_default(person_by_login_path(:login => current_user.login))
    else
      @display_user.login = @display_user.login_was unless @display_user.errors[:login].blank?
      if request.env['HTTP_REFERER'] =~ /edit_after_auth/
        render :action => 'edit_after_auth', :login => @original_user.login
      else
        render :action => 'edit', :login => @original_user.login
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
        flash[:error] = "Couldn't find a user matching #{params[:id]}"
      end
    end
  end

protected

  def add_friend
    error_msg, notice_msg = [nil, nil]
    friend_user = User.find_by_id(params[:friend_id])
    if friend_user.blank? || friendship = current_user.friendships.find_by_friend_id(friend_user.id)
      error_msg = "Either that user doesn't exist or you are already following them."
    else
      notice_msg = "You are now following #{friend_user.login}."
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
      notice_msg = "You are no longer following #{friendship.friend.login}."
      friendship.destroy
    else
      error_msg = "You aren't following that person."
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
      flash[:error] = "You must specify and confirm a new password."
      return redirect_to(edit_person_path(@user))
    end
    
    current_user.password = params[:password]
    current_user.password_confirmation = params[:password_confirmation]
    begin
      current_user.save!
      flash[:notice] = 'Successfully changed your password.'
    rescue ActiveRecord::RecordInvalid => e
      flash[:error] = "Couldn't change your password: #{e}"
      return redirect_to(edit_person_path(@user))
    end
    redirect_to(person_by_login_path(:login => current_user.login))
  end
  
  def find_user
    params[:id] ||= params[:login]
    begin
      @user = User.find(params[:id])
    rescue
      @user = User.find_by_login(params[:id])
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
    
end
