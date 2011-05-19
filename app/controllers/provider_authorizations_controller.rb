class ProviderAuthorizationsController < ApplicationController
  before_filter :login_required, :only => [:destroy]
  
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
    if auth_info["provider"]=='facebook' 
      # omniauth bug sets fb nickname to 'profile.php?id=xxxxx' if no other nickname exists
      auth_info["user_info"]["nickname"] = nil if (auth_info["user_info"]["nickname"] && auth_info["user_info"]["nickname"].match("profile.php"))
      # for some reason, omniauth doesn't populate image url
      # (maybe cause our version of omniauth was pre- fb graph api?)
      auth_info["user_info"]["image"] = "http://graph.facebook.com/#{auth_info["uid"]}/picture?type=large"
    end
    logger.debug("auth_info: " + auth_info.inspect)
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
        flash[:allow_edit_after_auth] = true
        redirect_to edit_after_auth_url and return
      end
    else # existing provider + inat user, so log him in
      self.current_user = existing_authorization.user
      handle_remember_cookie! true # set 'remember me' to true
      flash[:notice] = "Welcome back!"
    end
    redirect_back_or_default(edit_user_path(current_user)) and return
  end

end
