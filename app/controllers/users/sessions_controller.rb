class Users::SessionsController < Devise::SessionsController
  def create
    # attempt straight db auth first, then warden auth
    resource = legacy_authenticate if CONFIG.legacy && CONFIG.legacy.rest_auth
    resource ||= User.authenticate(params[:login], params[:password]) if params[:login] && params[:password]
    resource ||= warden.authenticate!(auth_options)
    throw(:warden) unless resource
    set_flash_message(:notice, :signed_in) if is_navigational_format?
    sign_in(resource_name, resource)
    last_ip = request.env['REMOTE_ADDR']
    last_ip = request.env["HTTP_X_FORWARDED_FOR"] if last_ip.split(".")[0..1].join(".") == "10.183"
    last_ip = request.env["HTTP_X_CLUSTER_CLIENT_IP"] if last_ip.split(".")[0..1].join(".") == "10.183"
    resource.update_attribute(:last_ip, last_ip)
    respond_to do |format|
      format.any(:html, :mobile) do
        flash.delete(:notice)
        if session[:return_to]
          redirect_to session[:return_to]
        else
          redirect_to after_sign_in_path_for(resource)
        end
      end

      # for reasons that are unclear iPhone requests for /sessions.json are 
      # considered mobile, even though request.format is text/html, which also 
      # makes no sense.
      format.json do
        render :json => current_user.to_json(:except => [
          :encrypted_password, 
          :password_salt,
          :remember_token,
          :remember_token_expires_at,
          :confirmation_token,
          :confirmed_at,
          :state,
          :deleted_at,
          :old_preferences,
          :icon_url,
          :remember_created_at
        ])
      end
    end
  end

  def destroy
    super { flash.delete(:notice) }
  end

  private
  def set_flash_message(key, kind, options = {})
    if @legacy_authentication_successful
      flash[:notice] = I18n.t(:legacy_authentication_notice_html, :url => generic_edit_user_url)
    else
      super
    end
  end

  # Sign a user in using legacy auth information if present
  def legacy_authenticate
    unless CONFIG.legacy && CONFIG.legacy.rest_auth && 
        CONFIG.legacy.rest_auth.REST_AUTH_SITE_KEY && CONFIG.legacy.rest_auth.REST_AUTH_DIGEST_STRETCHES
      return false
    end
    login = params[:login]
    password = params[:password]
    if params[:user]
      login ||= params[:user][:email] || params[:user][:login]
      password ||= params[:user][:password]
    end
    user = User.find_by_login(login)
    user ||= User.find_by_email(login)
    return false unless user
    pepper = CONFIG.legacy.rest_auth.REST_AUTH_SITE_KEY
    stretches = CONFIG.legacy.rest_auth.REST_AUTH_DIGEST_STRETCHES
    digest = Devise::Encryptable::Encryptors::RestfulAuthenticationSha1.digest(password, stretches, user.password_salt, pepper)
    if Devise.secure_compare(digest, user.encrypted_password)
      @legacy_authentication_successful = true
      user
    else
      false
    end
  end
end
