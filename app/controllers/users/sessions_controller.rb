class Users::SessionsController < Devise::SessionsController
  def create
    # attempt straight db auth first, then warden auth
    resource = if params[:login] && params[:password]
      User.authenticate(params[:login], params[:password])
    else
      warden.authenticate!(auth_options)
    end
    throw(:warden) unless resource
    set_flash_message(:notice, :signed_in) if is_navigational_format?
    sign_in(resource_name, resource)
    respond_with resource do |format|
      format.any(:html, :mobile) do
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
end
