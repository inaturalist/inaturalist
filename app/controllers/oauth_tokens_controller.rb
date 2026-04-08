class OauthTokensController < Doorkeeper::TokensController
  include Shared::FiltersModule
  prepend_before_action :set_request_locale, :set_site

  # Override the doorkeeper method to provide more helpful error messages when
  # auth fails. Note the OAuth spec enforces the status, keys, and the
  # `error` of the response, but not the `error_description`. Note that there
  # a few other solutions to this at
  # https://github.com/doorkeeper-gem/doorkeeper/issues/315
  def create
    super
    resource_owner_id = authorize_response.try(:token).try(:resource_owner_id)
    user = User.find_by_id( resource_owner_id ) unless resource_owner_id.blank?
    # A suspended user might have a valid access token
    if user&.suspended?
      raise INat::Auth::SuspendedError.new( user.inactive_message, suspended_until: user.suspended_until )
    end
  rescue INat::Auth::BadUsernamePasswordError
    headers.delete "WWW-Authenticate"
    self.status = 400
    self.response_body = {
      error: "invalid_grant",
      error_description: I18n.t( "devise.failure.invalid" )
    }.to_json
  rescue INat::Auth::SuspendedError => e
    headers.delete "WWW-Authenticate"
    self.status = 401
    self.response_body = {
      error: "suspended",
      error_description: e.message.presence || I18n.t( :this_user_has_been_suspended ),
      suspended_until: e.suspended_until&.iso8601
    }.to_json
  rescue INat::Auth::ChildWithoutPermissionError
    headers.delete "WWW-Authenticate"
    self.status = 400
    self.response_body = {
      error: "invalid_grant",
      error_description: I18n.t( :please_ask_your_parents_for_permission )
    }.to_json
  rescue INat::Auth::UnconfirmedError
    headers.delete "WWW-Authenticate"
    self.status = 400
    self.response_body = {
      error: "invalid_grant",
      error_description: I18n.t( "devise.failure.unconfirmed" )
    }.to_json
  rescue INat::Auth::UnconfirmedAfterGracePeriodError
    headers.delete "WWW-Authenticate"
    self.status = 400
    self.response_body = {
      error: "invalid_grant",
      error_description: I18n.t(
        :email_conf_required_after_grace_period,
        requirement_date: I18n.l( User::EMAIL_CONFIRMATION_REQUIREMENT_DATETIME.to_date, format: :long )
      )
    }.to_json
  end
end
