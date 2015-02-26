class ProviderOauthController < ApplicationController
  before_filter :authenticate_user!, :only => [:bounce_back]
  # OAuth2 assertion flow: http://tools.ietf.org/html/draft-ietf-oauth-assertions-01#section-6.3
  # Accepts Facebook and Google access tokens and returns an iNat access token
  def assertion
    assertion_type = params[:assertion_type] || params[:grant_type]
    client = Doorkeeper::Application.find_by_uid(params[:client_id])
    if assertion_type.blank? || client.blank?
      render :status => :unauthorized, :json => { :error => :access_denied }
      return
    end
    access_token = case assertion_type
    when /facebook/
      oauth_access_token_from_facebook_token(params[:client_id], params[:assertion])
    when /google/
      oauth_access_token_from_google_token(params[:client_id], params[:assertion])
    end

    if access_token
      auth = Doorkeeper::OAuth::TokenResponse.new(access_token)
      if request.format && request.format.json?
        render :json => auth.body, :status => auth.status
      else
        uri = URI.parse(access_token.application.redirect_uri)
        uri.query = Rack::Utils.build_query(
          :access_token => auth.token.token,
          :token_type   => auth.token.token_type,
          :expires_in   => auth.token.expires_in
        )
        redirect_to uri.to_s
      end
    else
      render :status => :unauthorized, :json => { :error => :access_denied }
    end
  end

  def bounce
    unless ProviderAuthorization::PROVIDERS.include?(params[:provider])
      return render_404
    end
    # store request params in session
    session[:oauth_bounce] = {
      :client_id => params[:client_id],
      :provider => params[:provider]
    }
    if logged_in?
      redirect_to oauth_bounce_back_url
    else
      # redirect to auth url for specified provider
      redirect_to auth_url_for(params[:provider])
    end
  end

  def bounce_back
    # get original request params form session
    original_params = session.delete(:oauth_bounce)
    return render_404 if original_params.blank?
    return render_404 unless client = Doorkeeper::Application.find_by_uid(original_params[:client_id])

    # find or create create an auth token
    access_token = Doorkeeper::AccessToken.
      where(:application_id => client.id, :resource_owner_id => current_user.id, :revoked_at => nil).
      order('created_at desc').
      limit(1).
      first
    if client.trusted?
      access_token ||= Doorkeeper::AccessToken.create!(
        :application_id    => client.id,
        :resource_owner_id => current_user.id,
      )
    end

    if access_token
      # redirect to client redirect_uri with token
      uri = URI.parse(access_token.application.redirect_uri)
      uri.query = Rack::Utils.build_query(
        :access_token => access_token.token,
        :token_type   => access_token.token_type,
        :expires_in   => access_token.expires_in
      )
      redirect_to uri.to_s
    else
      redirect_to oauth_authorization_url(:client_id => client.uid, :redirect_uri => client.redirect_uri, :response_type => "code")
    end
  end

  private
  def oauth_access_token_from_facebook_token(client_id, provider_token)
    client = Doorkeeper::Application.find_by_uid(client_id)
    return nil unless client
    user = if (pa = ProviderAuthorization.where(:provider_name => "facebook", :token => provider_token).first)
      pa.user
    end
    user ||= begin
      fb = Koala::Facebook::GraphAndRestAPI.new(provider_token)
      r = fb.get_object('me')
      user = User.joins(:provider_authorizations).
        where("provider_authorizations.provider_uid = ?", r['id']).
        where("provider_authorizations.provider_name = 'facebook'").
        first
      user ||= User.where("email = ?", r['email']).first
      if user.blank?
        uid = r['id']
        auth_info = {
          'provider' => 'facebook',
          'uid' => uid,
          'info' => {
            'nickname' => r['username'],
            'email' => r['email'],
            'name' => r['name'],
            'first_name' => r['first_name'],
            'last_name' => r['last_name'],
            'image' => "http://graph.facebook.com/#{uid}/picture?type=square",
            'description' => r['bio'],
            'urls' => {
              'Facebook' => r['link'],
              'Website' => r['website']
            },
            'location' => (r['location'] || {})['name'],
            'verified' => r['verified']
          },
          'credentials' => {
            'token' => provider_token
          }
        }
        user = User.create_from_omniauth(auth_info)
      end
      user
    rescue Koala::Facebook::AuthenticationError => e
      Rails.logger.debug "[DEBUG] Failed to get fb user info from token: #{e}"
      nil
    end
    return nil unless user
    access_token = Doorkeeper::AccessToken.
      where(:application_id => client.id, :resource_owner_id => user.id, :revoked_at => nil).
      order('created_at desc').
      limit(1).
      first
    if client.trusted?
      access_token ||= Doorkeeper::AccessToken.create!(
        :application_id    => client.id,
        :resource_owner_id => user.id,
      )
    end
    access_token
  end

  def oauth_access_token_from_google_token(client_id, provider_token)
    client = Doorkeeper::Application.find_by_uid(client_id)
    user = if (pa = ProviderAuthorization.where(:provider_name => "google_oauth2", :token => provider_token).first)
      pa.user
    end
    user ||= begin
      gclient = Google::APIClient.new
      gclient.authorization.client_id = CONFIG.google.client_id
      gclient.authorization.client_secret = CONFIG.google.secret
      gclient.authorization.access_token = provider_token
      gclient.authorization.scope = 'https://www.googleapis.com/auth/plus.login https://www.googleapis.com/auth/plus.me https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile'
      goauth2 = gclient.discovered_api('oauth2')
      r = gclient.execute(:api_method => goauth2.userinfo.get)
      json = JSON.parse(r.body)
      unless uid = json['id']
        Rails.logger.debug "[DEBUG] Google auth failed: #{json.inspect}"
        return nil
      end
      user = User.joins(:provider_authorizations).
        where("provider_authorizations.provider_uid = ?", uid).
        where("provider_authorizations.provider_name = 'google_oauth2'").
        first
      if user.blank?
        auth_info = {
          'provider' => 'google_oauth2',
          'uid' => uid,
          'info' => {
            'email' => json['email'],
            'name' => json['name'],
            'first_name' => json['first_name'],
            'last_name' => json['last_name'],
            'image' => json['picture'],
            'urls' => {
              'Google Plus' => json['link']
            },
            'verified' => json['verified_email']
          },
          'credentials' => {
            'token' => provider_token
          }
        }
        if auth_info['info']['image'].blank?
          gplus = gclient.discovered_api('plus')
          r = gclient.execute(
            :api_method => gplus.people.get,
            :parameters => {'collection' => 'public', 'userId' => 'me'}
          )
          json = JSON.parse(r.body)
          auth_info['info']['name'] ||= json['displayName']
          auth_info['info']['first_name'] ||= json['givenName']
          auth_info['info']['last_name'] ||= json['familyName']
          auth_info['info']['image'] ||= json['image'].try(:[], 'url')
          auth_info['info']['description'] ||= json['aboutMe']
        end
        user = User.create_from_omniauth(auth_info)
      end
      user
    rescue Google::APIClient::ClientError => e
      Rails.logger.debug "[DEBUG] Failed to make a Google API call: #{e}"
      nil
    end

    return nil unless user && user.persisted?
    access_token = Doorkeeper::AccessToken.
      where(:application_id => client.id, :resource_owner_id => user.id, :revoked_at => nil).
      order('created_at desc').
      limit(1).
      first
    if client.trusted?
      access_token ||= Doorkeeper::AccessToken.create!(
        :application_id    => client.id,
        :resource_owner_id => user.id,
      )
    end
    access_token
  end
end
