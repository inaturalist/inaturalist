# frozen_string_literal: true

class ProviderOauthController < ApplicationController
  skip_before_action :verify_authenticity_token

  layout "bootstrap"

  # OAuth2 assertion flow: http://tools.ietf.org/html/draft-ietf-oauth-assertions-01#section-6.3
  # Accepts Apple and Google access tokens and returns an iNat access token
  def assertion
    assertion_type = params[:assertion_type] || params[:grant_type]
    client = Doorkeeper::Application.find_by_uid( params[:client_id] )
    if client.blank?
      return render status: :bad_request, json: {
        error: "invalid_client",
        error_description: t( "doorkeeper.errors.messages.access_denied" )
      }
    end
    unless client.trusted?
      return render status: :bad_request, json: {
        error: "unauthorized_client",
        error_description: t( "doorkeeper.errors.messages.access_denied" )
      }
    end
    access_token = begin
      Timeout.timeout( 10 ) do
        case assertion_type
        when /google/
          oauth_access_token_from_google_token( client, params[:assertion] )
        when /apple/
          oauth_access_token_from_apple_assertion( client, params[:assertion] )
        else
          raise INat::Auth::BadAssertionTypeError
        end
      end
    rescue Timeout::Error
      # Not a part of the oauth spec: https://datatracker.ietf.org/doc/html/rfc6749
      render status: :gateway_timeout, json: {
        error: "timeout",
        error_description: t( "doorkeeper.errors.messages.temporarily_unavailable" )
      }
      return
    rescue INat::Auth::BadAssertionTypeError
      return render status: :bad_request, json: {
        error: "unsupported_grant_type",
        error_description: t( "doorkeeper.errors.messages.access_denied" )
      }
    rescue INat::Auth::MissingEmailError
      render status: :bad_request, json: {
        error: "invalid_grant",
        error_description: t( :provider_without_email_error_generic ).to_s.gsub( /\s+/, " " )
      }
      return
    rescue INat::Auth::SuspendedError
      return render status: :bad_request, json: {
        error: "invalid_grant",
        error_description: t( :this_user_has_been_suspended )
      }
    rescue INat::Auth::ChildWithoutPermissionError
      render status: :bad_request, json: {
        error: "invalid_grant",
        error_description: t( "please_ask_your_parents_for_permission" )
      }
      return
    rescue INat::Auth::UnconfirmedError
      render status: :bad_request, json: {
        error: "invalid_grant",
        error_description: t( "devise.failure.unconfirmed" )
      }
      return
    rescue INat::Auth::UnconfirmedAfterGracePeriodError
      render status: :bad_request, json: {
        error: "invalid_grant",
        error_description: I18n.t(
          :email_conf_required_after_grace_period,
          requirement_date: I18n.l( User::EMAIL_CONFIRMATION_REQUIREMENT_DATETIME.to_date, format: :long )
        )
      }
      return
    end

    if access_token
      auth = Doorkeeper::OAuth::TokenResponse.new( access_token )
      # The following frmat stuff is a hack around a bug in the Android app;
      # remove when possible
      if request&.format&.json? || ( params[:frmat] && params[:frmat] == "json" )
        render json: auth.body, status: auth.status
      else
        uri = URI.parse( access_token.application.redirect_uri )
        uri.query = Rack::Utils.build_query(
          access_token: auth.token.token,
          token_type: auth.token.token_type,
          expires_in: auth.token.expires_in
        )
        redirect_to uri.to_s
      end
    else
      render status: :bad_request, json: {
        error: "invalid_grant",
        error_description: t( "doorkeeper.errors.messages.access_denied" )
      }
    end
  end

  private

  def oauth_access_token_from_google_token( client, provider_token )
    user = if ( pa = ProviderAuthorization.where( provider_name: "google_oauth2", token: provider_token ).first )
      pa.user
    end
    user ||= begin
      r = RestClient.get( "https://www.googleapis.com/userinfo/v2/me", {
        Authorization: "Bearer #{provider_token}",
        "User-Agent" => "iNaturalist/Google"
      } )
      json = JSON.parse( r.body )
      unless ( uid = json["id"] )
        Rails.logger.debug "[DEBUG] Google auth failed: #{json.inspect}"
        return nil
      end
      user = User.joins( :provider_authorizations ).
        where( "provider_authorizations.provider_uid = ?", uid ).
        where( "provider_authorizations.provider_name = 'google_oauth2'" ).
        first
      if user.blank?
        auth_info = {
          "provider" => "google_oauth2",
          "uid" => uid,
          "info" => {
            "email" => json["email"],
            "name" => json["name"],
            "first_name" => json["given_name"],
            "last_name" => json["family_name"],
            "image" => json["picture"],
            "urls" => {
              "Google Plus" => json["link"]
            },
            "verified" => json["verified_email"]
          },
          "credentials" => {
            "token" => provider_token
          }
        }
        user = User.create_from_omniauth( auth_info, client )
        raise INat::Auth::MissingEmailError if !user.valid? && !user.errors[:email].blank?
      end
      user
    rescue RestClient::Unauthorized => e
      Rails.logger.debug "[DEBUG] Failed to make a Google API call: #{e}"
      nil
    end
    return nil unless user&.persisted?

    assertion_access_token_for_client_and_user( client, user )
  end

  def oauth_access_token_from_apple_assertion( client, assertion )
    # Note that the assertion we are expecting from our own iPhone app is a JSON
    # string that contains the identity token as well as name details that are
    # (apprently) only available to the app
    assertion_json = begin
      JSON.parse( assertion )
    rescue JSON::ParserError, TypeError => e
      Rails.logger.error "Failed to parse Apple assertion: #{e}"
      Logstasher.write_exception( e, request: request, session: session, user: current_user )
      return
    end
    id_token = assertion_json["id_token"]
    if id_token.blank?
      error_message = "Failed to parse id_token out of Apple assertion"
      Rails.logger.error = error_message
      LogStasher.write_hash(
        error_message: error_message,
        request: request,
        session: session,
        user: current_user
      )
      return
    end
    jwks = JSON.parse(
      RestClient.get( "https://appleid.apple.com/auth/keys" ).body,
      symbolize_names: true
    )
    # CONFIG.apple.client_id is the client ID for the *web*. Assertions from the
    # app will use the package ID... which should probably be specified
    # separately in the config, but this works for now
    iphone_app_id = CONFIG.apple.app_id
    # JWT is handling the JWS signature verification using the JWKs. That's a
    # lot of JW
    id_token_conents, _header = ::JWT.decode( id_token, nil, true, {
      verify_iss: true,
      iss: "https://appleid.apple.com",
      verify_iat: true,
      verify_aud: true,
      aud: [iphone_app_id], # .concat(options.authorized_client_ids),
      algorithms: ["RS256"],
      jwks: jwks
    } )
    # Verify the contents of the token
    issuer_is_apple = id_token_conents["iss"] == "https://appleid.apple.com"
    audience_is_inat = id_token_conents["aud"] == iphone_app_id
    token_is_current = Time.now < Time.at( id_token_conents["exp"] )
    unless issuer_is_apple && audience_is_inat && token_is_current
      error_message = <<~MSG
        Invalid identity token. iss: #{id_token_conents['iss']},
        aud: #{id_token_conents['aud']}, exp: #{id_token_conents['exp']}
      MSG
      Rails.logger.error = error_message
      LogStasher.write_hash(
        error_message: error_message,
        request: request,
        session: session,
        user: current_user
      )
      return
    end
    # Get the Apple unique user identifier (the "sub"ject)
    provider_uid = id_token_conents["sub"]
    if provider_uid.blank?
      error_message = "No user identifier in the Apple identity token"
      Rails.logger.error = error_message
      LogStasher.write_hash(
        error_message: error_message,
        request: request,
        session: session,
        user: current_user
      )
      return
    end
    existing_pa = ProviderAuthorization.where( provider_name: "apple", provider_uid: provider_uid ).first
    user = existing_pa&.user
    user ||= User.find_by_email( id_token_conents["email"] ) unless id_token_conents["email"].blank?
    unless user
      auth_info = {
        "provider" => "apple",
        "uid" => provider_uid,
        "info" => {
          "email" => id_token_conents["email"],
          "name" => assertion_json["name"],
          "verified" => id_token_conents["email_verified"] == "true"
        }
      }
      user = User.create_from_omniauth( auth_info, client )
      raise INat::Auth::MissingEmailError if !user.valid? && !user.errors[:email].blank?
    end
    return nil unless user&.persisted?

    if ( access_token = assertion_access_token_for_client_and_user( client, user ) )
      # We could get into a situation where the token was created but no
      # ProviderAuthorization records was created if an existing user was found
      # via email and User.create_from_omniauth wasn't called, so we make
      # absolutely sure it exists here
      existing_pa = ProviderAuthorization.where(
        provider_name: "apple",
        provider_uid: provider_uid
      ).first
      unless existing_pa
        ProviderAuthorization.create!(
          provider_name: "apple",
          provider_uid: provider_uid,
          user: user
        )
      end
    end
    access_token
  end

  def assertion_access_token_for_client_and_user( client, user )
    unless user.active_for_authentication?
      raise INat::Auth::SuspendedError if user.suspended?
      raise INat::Auth::ChildWithoutPermissionError if user.child_without_permission?
      raise INat::Auth::UnconfirmedAfterGracePeriodError if user.unconfirmed_grace_period_expired?
      raise INat::Auth::UnconfirmedError unless user.confirmed?
    end
    access_token = Doorkeeper::AccessToken.
      where( application_id: client.id, resource_owner_id: user.id, revoked_at: nil ).
      order( "created_at desc" ).
      limit( 1 ).
      first
    if client.trusted?
      if access_token
        # If the user already has a token for this client, ensure that the
        # scopes match what they're requesting
        access_token.update( scopes: scopes_from_params( params, client ) )
      else
        access_token = Doorkeeper::AccessToken.create!(
          application_id: client.id,
          resource_owner_id: user.id,
          scopes: scopes_from_params( params, client )
        )
      end
    end
    access_token
  end

  def scopes_from_params( params, client )
    allowed_scopes = client.scopes.try( :to_a ) || []
    requested_scopes = params[:scope].to_s.split( /\s/ ).compact.uniq
    scopes = allowed_scopes & requested_scopes
    scopes = Doorkeeper.configuration.default_scopes.to_a if scopes.blank?
    scopes.join( " " )
  end
end
