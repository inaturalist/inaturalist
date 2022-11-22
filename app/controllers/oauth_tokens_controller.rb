class OauthTokensController < Doorkeeper::TokensController
  include Shared::FiltersModule
  prepend_before_action :set_request_locale, :set_site

  def create
    super
    resource_owner_id = authorize_response.try(:token).try(:resource_owner_id)
    user = User.find_by_id( resource_owner_id ) unless resource_owner_id.blank?
    if user && user.suspended?
      headers.delete 'WWW-Authenticate'
      self.response_body = {
        error: "suspended",
        description: "User has been susppended"
      }.to_json
      self.status = 403
    end
  end
end
