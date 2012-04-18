class ProviderAuthorizationsController < ApplicationController
  before_filter :login_required, :only => [:destroy]
  protect_from_forgery :except => :create
  
  # This is kind of a dumb placeholder. OA calls through to the app before
  # doing its magic, so if this isn't here we get nonsense in the logs
  def blank
    # Dynamically set the permissions scope from the url
    if ProviderAuthorization::ALLOWED_SCOPES.include?(params[:scope].to_s)
      request.env['omniauth.strategy'].options[:scope] = params[:scope].to_sym
    end
    set_session_omniauth_scope
    render_404
  end

  # change the /auth/:provider/callback route to point to this if you want to examine the rack data returned by omniauth
  def auth_callback_test
    render(:text=>request.env['omniauth.auth'].to_yaml)
  end

  def failure
    flash[:notice] = "Hm, that didn't work. Try again or choose another login option."
    redirect_back_or_default login_url
  end

  def destroy
    if request.delete?
      provider = current_user.has_provider_auth(params[:provider])
      provider.destroy unless provider.nil?
    end
    redirect_to edit_person_url(current_user)
  end

  def create
    auth_info = request.env['omniauth.auth']
    
    case auth_info["provider"]
    when 'facebook'
      # omniauth bug sets fb nickname to 'profile.php?id=xxxxx' if no other nickname exists
      if auth_info["user_info"]["nickname"] && auth_info["user_info"]["nickname"].match("profile.php")
        auth_info["user_info"]["nickname"] = nil
      end
      # for some reason, omniauth doesn't populate image url
      # (maybe cause our version of omniauth was pre- fb graph api?)
      auth_info["user_info"]["image"] = "http://graph.facebook.com/#{auth_info["uid"]}/picture?type=large"
    when 'flickr'
      # construct the url for the user's flickr buddy icon
      nsid = auth_info['extra']['user_hash']['nsid']
      flickr_info = flickr.people.getInfo(:user_id=>nsid) # we make this api call to get the icon-farm and icon-server
      iconfarm = flickr_info['iconfarm']
      iconserver = flickr_info['iconserver']
      unless (iconfarm==0 || iconserver==0)
        auth_info["user_info"]["image"] = "http://farm#{iconfarm}.static.flickr.com/#{iconserver}/buddyicons/#{nsid}.jpg"
      end
    end
    
    
    if @provider_authorization = ProviderAuthorization.find_from_omniauth(auth_info)
      update_existing_provider_authorization(auth_info)
    else
      create_provider_authorization(auth_info)
    end
    
    if @provider_authorization && (scope = get_session_omniauth_scope)
      @provider_authorization.update_attribute(:scope, scope.to_s)
      session["omniauth_#{request.env['omniauth.strategy'].name}_scope"] = nil
    end
    
    if !session[:return_to].blank? && session[:return_to] != login_url
      @landing_path ||= session[:return_to]
    end
    
    # registering via an invite link in a flickr comment. see /flickr/invite
    if session[:invite_params]
      invite_params = session[:invite_params]
      session[:invite_params] = nil
      @landing_path = new_observation_url(invite_params)
      if @provider_authorization && @provider_authorization.created_at > 15.minutes.ago
        flash[:notice] = "Welcome to iNaturalist! If these options look good, " + 
          "click \"Save observation\" below and you'll be good to go!"
      end
    end
    
    redirect_to @landing_path || home_url
  end
  
  private
  def set_session_omniauth_scope
    return unless request.env['omniauth.strategy']
    session["omniauth_#{request.env['omniauth.strategy'].name}_scope"] = request.env['omniauth.strategy'].options[:scope]
  end
  
  def get_session_omniauth_scope
    session["omniauth_#{request.env['omniauth.strategy'].name}_scope"]
  end
  
  def create_provider_authorization(auth_info)
    email = auth_info.try(:[], 'user_info').try(:[], 'email')
    email ||= auth_info.try(:[], 'extra').try(:[], 'user_hash').try(:[], 'email')
    
    # if logged in or user with this email exists, link provider to existing inat user
    if current_user || (!email.blank? && self.current_user = User.find_by_email(email))
      @provider_authorization = current_user.add_provider_auth(auth_info)
      provider_name = auth_info['provider'].capitalize unless auth_info['provider']=='open_id'
      flash[:notice] = "You've successfully linked your #{provider_name} account."
      
    # create a new inat user and link provider to that user
    else
      logout_keeping_session!
      self.current_user = User.create_from_omniauth(auth_info)
      @provider_authorization = current_user.provider_authorizations.last
      handle_remember_cookie! true # set 'remember me' to true
      flash[:notice] = "Welcome!"
      if session[:invite_params].nil?
        flash[:allow_edit_after_auth] = true
        @landing_path = edit_after_auth_url
        return
      end
    end
    
    @landing_path ||= edit_user_path(current_user)
  end
  
  def update_existing_provider_authorization(auth_info)
    self.current_user = @provider_authorization.user
    handle_remember_cookie! true # set 'remember me' to true
    @provider_authorization.update_with_auth_info(auth_info)
    flash[:notice] = "Welcome back!"
    if get_session_omniauth_scope.to_s == 'write' && @provider_authorization.scope != 'write'
      flash[:notice] = "You just authorized iNat to write to your account " +
        "on #{@provider_authorization.provider_name}. Thanks! Please try " +
        "what you were doing again.  We promise to be careful!"
    end
    @landing_path = session[:return_to] || home_path
  end

end
