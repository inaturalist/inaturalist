class Users::RegistrationsController < Devise::RegistrationsController
  include Users::CustomDeviseModule

  skip_before_action :verify_authenticity_token

  def permit_params
    return unless params[:user]
    params.require(:user).permit(
      :birthday,
      :description,
      :data_transfer_consent,
      :email,
      :icon,
      :icon_url,
      :locale,
      :login,
      :name,
      :password,
      :password_confirmation,
      :pi_consent,
      :place_id,
      :preferred_observation_fields_by,
      :preferred_observation_license,
      :preferred_photo_license,
      :preferred_sound_license,
      :prefers_community_taxa,
      :time_zone
    )
  end

  def create
    build_resource( permit_params )
    resource.site = @site

    requestor_ip = Logstasher.ip_from_request_env(request.env)
    resource.last_ip = requestor_ip

    if @site.using_recaptcha? && !is_mobile_app? && !request.format.json?
      if !GoogleRecaptcha.verify_recaptcha( response: params["g-recaptcha-response"],
                                            remoteip: requestor_ip,
                                            secret: @site.google_recaptcha_secret )
        errors = [ I18n.t( :recaptcha_verification_failed ) ]
        resource.errors.add(:recaptcha, I18n.t( :recaptcha_verification_failed ) )
      end
    end

    if User.ip_address_is_often_suspended( requestor_ip )
      errors ||= []
      errors << I18n.t( :there_was_a_problem_creating_this_account )
      resource.errors.add( :recaptcha, I18n.t( :there_was_a_problem_creating_this_account ) )
      Logstasher.write_custom_log(
        "User create failed: #{requestor_ip}", request: request, session: session, user: resource )
    end

    # If for some reason a user is already signed in, don't allow them to make
    # another user
    if current_user && current_user.id != Devise::Strategies::ApplicationJsonWebToken::ANONYMOUS_USER_ID
      errors ||= []
      errors << I18n.t( :user_already_authenticated )
    end

    unless errors
      resource.wait_for_index_refresh = true
      resource.oauth_application_id = oauth_application_from_user_agent.try(:id) || OauthApplication::WEB_APP_ID
      if resource.save
        if resource.active_for_authentication?
          set_flash_message :notice, :signed_up if is_navigational_format?
          sign_in(resource_name, resource)
          respond_with(resource) do |format|
            format.html do
              if session[:return_to_for_new_user]
                redirect_to session[:return_to_for_new_user]
              elsif session[:return_to]
                redirect_to session[:return_to]
              else
                redirect_to home_path( new_user: true )
              end
            end
            format.json do
              render :json => resource.as_json(User.default_json_options)
            end
          end
          return
        else
          msg = case resource.inactive_message
          when "inactive"
            t( "devise.registrations.signed_up_but_inactive" )
          when "locked"
            t( "devise.registrations.signed_up_but_locked" )
          when "unconfirmed"
            t( "devise.registrations.signed_up_but_unconfirmed" )
          else
            t( "devise.registrations.signed_up_but_#{resource.inactive_message}" )
          end
          flash[:notice] = msg if is_navigational_format?
          expire_data_after_sign_in!
          respond_with( resource ) do | format |
            format.json { render status: :created, json: { message: msg } }
            format.html { redirect_to root_url }
          end
          return
        end
      else
        errors = resource.errors.full_messages
      end
    end

    clean_up_passwords resource
    respond_with(resource) do |format|
      format.html { render :new }
      format.json { render json: { errors: errors }, status: :unprocessable_entity }
    end
  end

  private

  def oauth_application_from_user_agent
    case request.user_agent
    when /^iNaturalist\/\d+.*Build.*Android/ then OauthApplication.inaturalist_android_app
    when /^iNaturalist\/\d+.*CFNetwork.*Darwin/ then OauthApplication.inaturalist_iphone_app
    when /^Seek\/\d+.*Handset/ then OauthApplication.seek_app
    end
  end

end
