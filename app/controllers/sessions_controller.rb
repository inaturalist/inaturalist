# This controller handles the login/logout function of the site.  
class SessionsController < ApplicationController
  
  MOBILIZED = [:new]
  before_filter :unmobilized, :except => MOBILIZED
  before_filter :mobilized, :only => MOBILIZED
  
  def new
    respond_to do |format|
      format.html
      format.mobile
    end
  end

  def create
    logout_keeping_session!
    user = User.authenticate(params[:login], params[:password])
    if user
      # Protects against session fixation attacks, causes request forgery
      # protection if user resubmits an earlier form using back
      # button. Uncomment if you understand the tradeoffs.
      # reset_session
      self.current_user = user
      new_cookie_flag = (params[:remember_me] == "1")
      handle_remember_cookie! new_cookie_flag
      user.update_attribute(:last_ip, request.env['REMOTE_ADDR'])
      
      respond_to do |format|
        format.html do
          flash[:notice] = "Logged in successfully"
          if !session[:return_to].blank? && 
              ![login_url, root_url, login_path, root_path].include?(session[:return_to])
            redirect_to session[:return_to]
          else
            redirect_to home_path
          end
        end
        
        format.json do
          render :json => current_user.to_json(:except => [
            :crypted_password, :salt, :old_preferences, :activation_code, 
            :remember_token, :last_ip])
        end
      end
    else
      note_failed_signin
      @login       = params[:login]
      @remember_me = params[:remember_me]
      @msg = "Couldn't log you in as '#{params[:login]}'"
      respond_to do |format|
        format.html do
          flash[:error] = @msg
          render :action => 'new'
        end
        format.json do
          render :status => :unprocessable_entity, :json => {:error => @msg}
        end
      end
      
    end
  end

  def destroy
    logout_killing_session!
    flash[:notice] = "You have been logged out. Come back soon!"
    redirect_back_or_default('/')
  end

protected
  # Track failed login attempts
  def note_failed_signin
    logger.warn "Failed login for '#{params[:login]}' from #{request.remote_ip} at #{Time.now.utc}"
  end
end
