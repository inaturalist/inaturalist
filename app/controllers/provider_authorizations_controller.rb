# frozen_string_literal: true

class ProviderAuthorizationsController < ApplicationController
  before_action :doorkeeper_authorize!,
    only: [:destroy],
    if: -> { authenticate_with_oauth? }
  before_action :authenticate_user!, only: [:destroy],
    unless: -> { authenticated_with_oauth? }
  protect_from_forgery prepend: true, except: :create, with: :exception,
    if: -> { request.headers["Authorization"].blank? }

  # change the /auth/:provider/callback route to point to this if you want to examine the rack data returned by omniauth
  def auth_callback_test
    # render(:json=>request.env['omniauth.auth'].to_json)
  end

  def failure
    flash[:notice] = params[:message] || "Sorry, that login provider couldn't sign you in."
    redirect_back_or_default login_url
  end

  def destroy
    return render_404 unless request.delete?

    provider_authorization = current_user.has_provider_auth( params[:provider] ) unless params[:provider].blank?
    provider_authorization ||= current_user.provider_authorizations.find_by_id( params[:id] )
    provider_authorization&.destroy
    respond_to do | format |
      format.html do
        flash[:notice] = if provider_authorization
          t( :you_unlinked_your_provider_account,
            provider: ProviderAuthorization::PROVIDER_NAMES[provider_authorization.provider_name] )
        else
          t( :failed_to_unlink_your_account )
        end
        redirect_to edit_person_url( current_user )
      end
      format.json do
        if provider_authorization
          head :no_content
        else
          render status: :unprocessable_entity, json: {
            error: t( :failed_to_unlink_account )
          }
        end
      end
    end
  end

  def create
    auth_info = request.env["omniauth.auth"]
    case auth_info["provider"]
    when "flickr"
      if auth_info["info"]["image"].blank?
        # construct the url for the user's flickr buddy icon
        nsid = auth_info["uid"]
        # we make this api call to get the icon-farm and icon-server
        flickr_info = flickr.people.getInfo( user_id: nsid )
        iconfarm = flickr_info["iconfarm"]
        iconserver = flickr_info["iconserver"]
        unless iconfarm.zero? || iconserver.zero?
          auth_info["info"]["image"] = "http://farm#{iconfarm}.static.flickr.com/#{iconserver}/buddyicons/#{nsid}.jpg"
        end
      end
    when "apple"
      if auth_info["info"]["name"] && auth_info["info"]["name"]["firstName"]
        full_name = auth_info["info"]["name"]["firstName"]
        if auth_info["info"]["name"]["lastName"]
          full_name += " #{auth_info['info']['name']['lastName']}"
        end
        auth_info["info"]["name"] = full_name
      end
    end

    if ( existing_authorization = ProviderAuthorization.find_from_omniauth( auth_info ) )
      if logged_in? && existing_authorization.user != current_user
        flash[:alert] = t( :that_account_is_already_connected )
      else
        @provider_authorization = existing_authorization
        update_existing_provider_authorization( auth_info )
      end
    else
      create_provider_authorization( auth_info )
      return redirect_back_or_default @landing_path || home_url
    end

    if @provider_authorization&.valid? && ( scope = get_session_omniauth_scope )
      @provider_authorization.update( scope: scope.to_s )
      session["omniauth_#{request.env['omniauth.strategy'].name}_scope"] = nil
    end

    if !session[:return_to].blank? && session[:return_to] != login_url
      @landing_path ||= session[:return_to]
    end

    # registering via an invite link in a flickr comment. see /flickr/invite
    if session[:invite_params]
      invite_params = session[:invite_params]
      session[:invite_params] = nil
      if @provider_authorization&.valid? && @provider_authorization.created_at > 15.minutes.ago
        flash[:notice] = "Welcome to #{@site.name}! If these options look good, " \
          "click \"Save observation\" below and you'll be good to go!"
        invite_params.merge!( welcome: true )
      end
      @landing_path = new_observation_url( invite_params )
    end
    redirect_to @landing_path || home_url
  end

  private

  def set_session_omniauth_scope
    return unless request.env["omniauth.strategy"]

    session["omniauth_#{request.env['omniauth.strategy'].name}_scope"] =
      request.env["omniauth.strategy"].options[:scope]
  end

  def get_session_omniauth_scope
    session["omniauth_#{request.env['omniauth.strategy'].name}_scope"]
  end

  def get_session_oauth_application
    return unless session[:return_to]

    return_to_query_params = Rack::Utils.parse_query( URI.parse( session["return_to"] ).query )
    return unless return_to_query_params && return_to_query_params["client_id"]

    OauthApplication.where( uid: return_to_query_params["client_id"] ).first
  end

  def create_provider_authorization( auth_info )
    email = auth_info.try( :[], "info" ).try( :[], "email" )
    email ||= auth_info.try( :[], "extra" ).try( :[], "user_hash" ).try( :[], "email" )

    existing_user = current_user
    existing_user ||= User.where( "lower(email) = ?", email.downcase ).first unless email.blank?
    if auth_info["provider"] == "flickr" && !auth_info["uid"].blank?
      existing_user ||= User.joins( :flickr_identity ).where( "flickr_identities.flickr_user_id = ?",
        auth_info["uid"] ).first
    end

    # if logged in or user with this email exists, link provider to existing inat user
    if existing_user
      sign_in( existing_user ) unless logged_in?
      @provider_authorization = current_user.add_provider_auth( auth_info )
      if @provider_authorization&.valid?
        flash[:notice] =
          t( :youve_successfully_linked_your_provider_account,
            provider: @provider_authorization.provider.to_s.capitalize )
      else
        msg = "There were problems linking your account"
        msg += ": #{@provider_authorization.errors.full_messages.to_sentence}" if @provider_authorization
        flash[:error] = msg
      end

    # create a new inat user and link provider to that user
    else
      sign_out( current_user ) if current_user
      user = User.create_from_omniauth( auth_info, get_session_oauth_application )
      unless user.valid?
        flash[:error] = if user.email.blank?
          case auth_info[:provider]
          when "apple" then t( "provider_without_email_error_apple" )
          when "flickr" then t( "provider_without_email_error_flickr" )
          when "google_oauth2" then t( "provider_without_email_error_google_oauth2" )
          else
            t( "provider_without_email_error_generic" )
          end
        else
          t( :failed_to_save_record_with_errors, errors: user.errors.full_messages.to_sentence )
        end
        return
      end
      @provider_authorization = user.provider_authorizations.last
      user.update( site: @site ) if @site
      if session[:invite_params].nil?
        flash[:allow_edit_after_auth] = true
        @landing_path = edit_after_auth_url
        return @provider_authorization
      end
      @landing_path = root_path
    end

    @landing_path ||= edit_user_path( current_user )
    @provider_authorization
  end

  def update_existing_provider_authorization( auth_info )
    sign_in @provider_authorization.user
    @provider_authorization.user.remember_me
    @provider_authorization.update_with_auth_info( auth_info )
    @provider_authorization.touch
    set_request_locale
    if get_session_omniauth_scope.to_s == "write" && @provider_authorization.scope != "write"
      flash[:notice] = "You just authorized #{@site.site_name_short} to write to your account " \
        "on #{@provider_authorization.provider}. Thanks! Please try " \
        "what you were doing again.  We promise to be careful!"
    end
    @landing_path = session[:return_to] || home_path
  end
end
