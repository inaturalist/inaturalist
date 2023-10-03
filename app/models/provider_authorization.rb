# frozen_string_literal: true

# would've liked to call this simply Authorization, but that model name clashes with restful_authentication
class ProviderAuthorization < ApplicationRecord
  belongs_to :user
  validates_presence_of :user_id, :provider_uid, :provider_name
  validates_uniqueness_of :provider_uid, scope: :provider_name
  validate :uniqueness_of_authorization_per_user
  after_save :create_photo_identity, :create_sound_identity
  after_destroy :destroy_photo_identity, :destroy_sound_identity

  # Hash that comes back from the provider through omniauth.  Should be set
  # after the callback gets fired, so in theory should only be available when
  # this record is created
  attr_accessor :auth_info

  PROVIDERS = %w(facebook twitter flickr google_oauth2 yahoo soundcloud orcid apple).freeze
  PROVIDER_NAMES = PROVIDERS.each_with_object( {} ) do | provider, memo |
    memo[provider] = case provider
    when "google_oauth2"
      "Google"
    when "soundcloud"
      "SoundCloud"
    when "orcid"
      "ORCID"
    else
      provider.capitalize
    end
  end
  AUTH_URLS = PROVIDERS.inject( {} ) do | memo, provider |
    memo.update( provider => "/auth/#{provider.downcase}" )
  end
  AUTH_URLS.merge!( "yahoo" => "/auth/open_id?openid_url=https://me.yahoo.com" )
  ALLOWED_SCOPES = %w(read write).freeze

  def to_s
    "<ProviderAuthorization #{id} user_id: #{user_id} provider_name: #{provider_name}>"
  end

  def uniqueness_of_authorization_per_user
    existing_scope = case provider_uid
    when %r{google.com/accounts}
      ProviderAuthorization.
        where( provider_name: "openid" ).
        where( "provider_uid LIKE 'https://www.google.com/accounts%'" )
    when /me.yahoo.com/
      ProviderAuthorization.
        where( provider_name: "openid" ).
        where( "provider_uid LIKE 'https://me.yahoo.com%'" )
    else
      ProviderAuthorization.where( provider_name: provider_name )
    end
    existing_scope = existing_scope.where( "id != ?", id ) if id
    if existing_scope.where( user_id: user_id ).exists?
      errors.add( :user_id, "has already linked an account with #{provider}" )
    end
    true
  end

  def provider
    if provider_uid =~ %r{google.com/accounts} || provider_name =~ /google/
      "google"
    elsif provider_uid =~ /me.yahoo.com/
      "yahoo"
    else
      provider_name
    end
  end

  def self.find_from_omniauth( auth_info )
    find_by_provider_name_and_provider_uid( auth_info["provider"], auth_info["uid"].to_s )
  end

  # Try to create a photo identity if the auth provider has/is a photo
  # service
  def create_photo_identity
    photo_identity = case provider_name
    when "flickr"
      return if user.flickr_identity
      return unless auth_info

      user.create_flickr_identity(
        flickr_user_id: provider_uid || auth_info["uid"],
        flickr_username: auth_info["name"],
        token: token,
        secret: auth_info["credentials"]["secret"],
        token_created_at: Time.now
      )
    end
    if photo_identity && !photo_identity.valid?
      Rails.logger.error "[ERROR #{Time.now}] Failed to save #{provider} " \
        "photo identity after saving provider auth: " +
        photo_identity.errors.full_messages.to_sentence
    end
    true
  end

  def create_sound_identity
    return unless provider_name == "soundcloud"
    return if user.soundcloud_identity || !auth_info

    user.create_soundcloud_identity(
      native_username: auth_info["info"]["nickname"],
      native_realname: auth_info["info"]["name"]
    )
  end

  # right now this only needs to happen for flickr
  def update_photo_identities
    return unless token
    return unless provider_name == "flickr"
    return unless ( fi = user.flickr_identity )

    fi.token = token
    secret = auth_info.try( :[], "credentials" ).try( :[], "secret" )
    fi.secret = secret unless secret.blank?
    fi.save
    true
  end

  def destroy_photo_identity
    if provider_name == "flickr"
      user&.flickr_identity&.destroy
    end
    true
  end

  def destroy_sound_identity
    if provider_name == "soundcloud"
      user&.soundcloud_identity&.destroy
    end
    true
  end

  def assign_auth_info( auth_info )
    @auth_info = auth_info
    self.provider_name ||= auth_info["provider"]
    self.provider_uid ||= auth_info["uid"]
    unless auth_info["credentials"] && credentials_needed_for_provider?( provider_name )
      return
    end

    assign_attributes(
      token: auth_info["credentials"]["token"] || auth_info["credentials"]["secret"],
      secret: auth_info["credentials"]["secret"],
      refresh_token: auth_info["credentials"]["refresh_token"]
    )
  end

  def credentials_needed_for_provider?( provider )
    case provider
    when "flickr", "google_oauth2"
      # For both Flickr and Google we need to hold on to a token to retrieve
      # photos for import
      true
    else
      # For everything else, we only store a record of authorization for the
      # purpose of sign in / log in (and generating a link in the case of
      # ORCID), so we don't need a token to read or write data after the
      # first auth event
      false
    end
  end

  def update_with_auth_info( auth_info )
    return unless auth_info["credentials"] # open_id (google, yahoo, etc) doesn't provide a token

    assign_auth_info( auth_info )
    save
    update_photo_identities
  end

  def photo_source_name
    provider_name =~ /google/ ? "picasa" : provider_name
  end

  # http://stackoverflow.com/questions/12792326/how-do-i-refresh-my-google-oauth2-access-token-using-my-refresh-token
  # http://stackoverflow.com/questions/17894192/how-do-i-get-back-a-refresh-token-for-rails-app-with-omniauth-google-oauth2
  # http://stackoverflow.com/questions/3487991/why-does-oauth-v2-have-both-access-and-refresh-tokens
  # https://developers.google.com/identity/protocols/OAuth2WebServer#refresh
  def refresh_access_token!
    return unless provider_name == "google_oauth2" # TODO: implement for other providers

    if refresh_token.blank?
      Rails.logger.error "[ERROR #{Time.now}] Refresh token missing for #{self}"
      return
    end
    options = {
      body: {
        client_id: CONFIG.google.client_id,
        client_secret: CONFIG.google.secret,
        refresh_token: refresh_token,
        grant_type: "refresh_token"
      },
      headers: {
        "Content-Type" => "application/x-www-form-urlencoded"
      }
    }
    response = HTTParty.post( "https://accounts.google.com/o/oauth2/token", options )
    if response.code == 200
      update_attribute( :token, response.parsed_response["access_token"] )
    else
      Rails.logger.debug "[DEBUG] Failed to refresh access token, #{response.body}"
      raise "Failed to refresh access token"
    end
  end
end
