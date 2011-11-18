class ProviderAuthorizationsController < ApplicationController
  before_filter :login_required, :only => [:destroy]
  protect_from_forgery :except => :create
  
  # This is kind of a dumb placeholder. OA calls through to the app before
  # doing its magic, so if this isn't here we get nonsense in the logs
  def blank
    render_404
  end

  # change the /auth/:provider/callback route to point to this if you want to examine the rack data returned by omniauth
  def auth_callback_test
    render(:text=>request.env['omniauth.auth'].to_yaml)
  end

  def failure
    flash[:notice] = "Hm, that didn't work. Try again or choose another login option."
    redirect_to login_url
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
      auth_info["user_info"]["nickname"] = nil if (auth_info["user_info"]["nickname"] && auth_info["user_info"]["nickname"].match("profile.php"))
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
    Rails.logger.debug "[DEBUG] auth_info: #{auth_info.inspect}"
    existing_authorization = ProviderAuthorization.find_from_omniauth(auth_info)
    if existing_authorization.nil?  # first time logging in with this provider + provider uid combo
      email = (auth_info["user_info"]["email"] || auth_info["extra"]["user_hash"]["email"])
      if current_user || (!email.blank? && self.current_user=User.find_by_email(email)) # if logged in or user with this email exists, link provider to existing inat user
        current_user.add_provider_auth(auth_info)
        flash[:notice] = "You've successfully linked your #{auth_info['provider'].capitalize unless auth_info['provider']=='open_id'} account."
      else # create a new inat user and link provider to that user
        logout_keeping_session!
        self.current_user = User.create_from_omniauth(auth_info)
        handle_remember_cookie! true # set 'remember me' to true
        flash[:notice] = "Welcome!"
        if session[:invite_params].nil?
          flash[:allow_edit_after_auth] = true
          redirect_to edit_after_auth_url and return
        end
      end
      landing_path = edit_user_path(current_user)
    else # existing provider + inat user, so log him in
      self.current_user = existing_authorization.user
      handle_remember_cookie! true # set 'remember me' to true
      existing_authorization.auth_info = auth_info
      existing_authorization.save
      flash[:notice] = "Welcome back!"
      landing_path = home_path
    end
    landing_path = session[:return_to] if !session[:return_to].blank? && session[:return_to] != login_url
    session[:return_to] = nil
    if session[:invite_params] # registering via an invite link in a flickr/fb comment. see /photos/invite
      invite_params = session[:invite_params]
      session[:invite_params] = nil
      redirect_to(new_observation_url(invite_params)) and return
    else
      redirect_to landing_path
    end
    return
  end

end
