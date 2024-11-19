class Users::SessionsController < Devise::SessionsController
  include Users::CustomDeviseModule

  protect_from_forgery with: :exception, prepend: true

  def create
    # attempt straight db auth first, then warden auth
    resource = legacy_authenticate if @site.legacy_rest_auth_key
    resource ||= User.authenticate(params[:login], params[:password]) if params[:login] && params[:password]
    resource ||= warden.authenticate!(auth_options)
    throw(:warden) unless resource
    set_flash_message(:notice, :signed_in) if is_navigational_format?
    sign_in(resource_name, resource)
    resource.update( last_ip: Logstasher.ip_from_request_env( request.env ) )
    respond_to do |format|
      format.html do
        flash.delete(:notice)
        if session[:return_to]
          redirect_to session[:return_to].gsub( /(%20|\s)/, "+" )
        else
          redirect_to after_sign_in_path_for(resource)
        end
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
    unless @site.legacy_rest_auth_key
      return false
    end
    login = params[:login]
    password = params[:password]
    if params[:user]
      login ||= params[:user][:email] || params[:user][:login]
      password ||= params[:user][:password]
    end
    user = User.find_by_login(login)
    user ||= User.find_by_email(login) unless login.blank?
    return false unless user
    pepper = @site.legacy_rest_auth_key
    stretches = 10
    digest = Devise::Encryptable::Encryptors::RestfulAuthenticationSha1.digest(password, stretches, user.password_salt, pepper)
    if Devise.secure_compare(digest, user.encrypted_password)
      @legacy_authentication_successful = true
      user
    else
      false
    end
  end
end
