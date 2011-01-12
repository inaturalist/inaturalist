class UsersController < ApplicationController  
  before_filter :login_required, :only => [:dashboard, :edit, :update]
  before_filter :find_user, :only => [:suspend, :unsuspend, :destroy, :purge, 
    :show, :edit, :update, :relationships, :add_role, :remove_role]
  before_filter :ensure_user_is_current_user_or_admin, :only => [:edit, :update, :destroy]
  before_filter :ensure_user_is_admin, :only => [:suspend, :unsuspend]
  
  def new
    @user = User.new
  end
 
  def create
    logout_keeping_session!
    @user = User.new(params[:user])
    @user.register! if @user && @user.valid?
    success = @user && @user.valid?
    if success && @user.errors.empty?
      redirect_back_or_default('/')
      flash[:notice] = "Thanks for signing up!  We're sending you an email with your activation code."
    else
      render :action => 'new'
    end
  end

  def activate
    logout_keeping_session!
    user = User.find_by_activation_code(params[:activation_code]) unless params[:activation_code].blank?
    case
    when (!params[:activation_code].blank?) && user && !user.active?
      user.activate!
      flash[:notice] = "Your iNaturalist.org account has been verified! Please sign in to continue."
      redirect_to '/login'
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
    @user.destroy
    flash[:notice] = "#{@user.login} removed from iNaturalist"
    redirect_to users_path
  end
  
  # Methods below here are added by iNaturalist
  
  def index
    update_find_options = {
      :limit => 10, 
      :order => "created_at DESC"
    }
    
    @updates = [
      Observation.find(:all, update_find_options),
      Identification.find(:all, update_find_options),
      Post.find(:all, update_find_options),
      Comment.find(:all, update_find_options)
    ].flatten.sort{|a,b| b.created_at <=> a.created_at}.group_by(&:user)


    find_options = {
      :page => params[:page] || 1, :order => 'login'
    }
    if @letter = params[:letter]
      find_options.update(:conditions => ["login LIKE ?", "#{params[:letter].first}%"])
    end
    @users = User.active.paginate(find_options)
    
    @users_by_letter = User.count(:group => "LOWER(LEFT(login, 1))")
    alphabet = %w"a b c d e f g h i j k l m n o p q r s t u v w x y z"
    @users_by_letter = alphabet.map do |letter|
      [letter, @users_by_letter[letter] || 0]
    end
  end
  
  def show
    @selected_user = @user
    @login = @selected_user.login
  end
  
  def relationships
    update_find_options = {
      :limit => 10, 
      :order => "created_at DESC"
    }
    
    # @updates = [
    #   Observation.find(:all, update_find_options),
    #   Identification.find(:all, update_find_options),
    #   Post.find(:all, update_find_options),
    #   Comment.find(:all, update_find_options)
    # ].flatten.sort{|a,b| b.created_at <=> a.created_at}.group_by(&:user)

    find_options = {
      :page => params[:page] || 1, :order => 'login'
    }
    if @letter = params[:letter]
      find_options.update(:conditions => [
        "login LIKE ?", "#{params[:letter].first}%"])
    end
    
    if (params[:following])
      @users = User.find_by_login(params[:login]).friends.paginate(find_options)
    elsif (params[:followers])
      @users = User.find_by_login(params[:login]).followers.paginate(find_options)
    end
    
    # @users_by_letter = User.count(:group => "LOWER(LEFT(login, 1))")
    # alphabet = %w"a b c d e f g h i j k l m n o p q r s t u v w x y z"
    # @users_by_letter = alphabet.map do |letter|
    #   [letter, @users_by_letter[letter] || 0]
    # end
    
    render :action => 'index'
    return
  end
  
  # These are protected by login_required
  def dashboard
    @user = current_user
    @recently_commented = Observation.all(
      :include => [:comments, :user, :photos],
      :conditions => [
        "observations.user_id = ? AND comments.created_at > ?", 
        @user, 1.week.ago],
      :order => "comments.created_at DESC"
    )
    
    if @recently_commented.empty?
      @commented_on = Observation.all(
        :include => [:comments, :user, :photos],
        :conditions => [
          "comments.user_id = ? AND comments.created_at > ?", 
          @user, 1.week.ago],
        :order => "comments.created_at DESC"
      ).uniq
    else
      @commented_on = Observation.all(
        :include => [:comments, :user, :photos],
        :conditions => [
          "comments.user_id = ? AND comments.created_at > ? AND observations.id NOT IN (?)", 
          @user, 1.week.ago, @recently_commented],
        :order => "comments.created_at DESC"
      ).uniq
    end
    
    per_page = params[:per_page] || 20
    per_page = 100 if per_page.to_i > 100
    @updates = current_user.activity_streams.paginate(
      :page => params[:page], 
      :per_page => per_page, 
      :order => "id DESC", 
      :include => [:user, :subscriber])
    
    return if @updates.blank?
    
    # Eager loading
    @activity_objects_by_update_id, @associates = 
      ActivityStream.eager_load_associates(@updates, 
        :batch_limit => 18,
        :includes => {
          "Observation" => [:user, {:taxon => :taxon_names}, :iconic_taxon, :photos],
          "Identification" => [:user, {:taxon => :taxon_names}, {:observation => :user}],
          "Comment" => [:user, :parent],
          "ListedTaxon" => [{:list => :user}, {:taxon => [:photos, :taxon_names]}]
        })
    
    @id_please_observations = @associates[:observations]
    if @id_please_observations && @commented_on
      @id_please_observations += @commented_on
    end
    unless @id_please_observations.blank?
      @id_please_observations = @id_please_observations.select(&:id_please?)
      @id_please_observations = @id_please_observations.uniq.sort_by(&:id).reverse
    end
  end
  
  def edit
  end
  
  def update
    @user = current_user
    @login = @user.login
    @original_user = @user
    
    # Add a friend
    unless params[:friend_id].blank?
      if (friend_user = User.find_by_id(params[:friend_id])) && !current_user.friends_with?(friend_user)
        flash[:notice] = "You are now following #{friend_user.login}."
        current_user.friends << friend_user
      else
        flash[:error] = "Either that user doesn't exist or you are already following them."
      end
      return redirect_back_or_default(person_by_login_path(:login => current_user.login))
    end
    
    # Remove a friend
    unless params[:remove_friend_id].blank?
      if friendship = current_user.friendships.find_by_friend_id(params[:remove_friend_id])
        flash[:notice] = "You are no longer following #{friendship.friend.login}."
        friendship.destroy
      else
        flash[:error] = "You aren't following that person."
      end
      return redirect_back_or_default(person_by_login_path(:login => current_user.login))
    end
    
    # Update passwords
    unless params[:password].blank?
      if current_user.authenticated?(params[:current_password])
        current_user.password = params[:password]
        current_user.password_confirmation = params[:password_confirmation]
        begin
          current_user.save!
          flash[:notice] = 'Successfully changed your password.'
        rescue ActiveRecord::RecordInvalid => e
          flash[:error] = "Couldn't change your password: #{e}"
          return redirect_to(edit_person_path(@user))
        end
      else
        flash[:error] = "Couldn't change your password: is that really your current password?"
        return redirect_to(edit_person_path(@user))
      end
      return redirect_to(person_by_login_path(:login => current_user.login))
    end
    
    # Update the preferences
    @user.preferences ||= Preferences.new
    if params[:user] && params[:user][:preferences]
      @user.preferences.update_attributes(params[:user][:preferences])
    end
    
    if @user.update_attributes(params[:user])
      flash[:notice] = 'Your profile was successfully updated!'
      redirect_to(person_by_login_path(:login => @user.login))
    else
      render :action => 'edit', :login => @original_user.login
    end
  end
  
  def curation
    @user = User.find_by_id(params[:id])
    @user ||= User.find_by_login(params[:id])
    if @user.blank? && !params[:id].blank?
      flash[:error] = "Couldn't find a user matching #{params[:id]}"
    end
  end

protected
  def find_user
    params[:id] ||= params[:login]
    begin
      @user = User.find(params[:id])
    rescue
      @user = User.find_by_login(params[:id])
      raise ActiveRecord::RecordNotFound if @user.nil?
    end
  end
  
  def ensure_user_is_current_user_or_admin
    unless current_user.has_role? :admin
      redirect_to edit_user_path(current_user, :id => current_user.login) if @user.id != current_user.id
    end
  end
  
  def ensure_user_is_admin
    unless current_user.has_role? :admin
      redirect_to user_path(current_user, :id => current_user.login)
    end
  end
    
end
