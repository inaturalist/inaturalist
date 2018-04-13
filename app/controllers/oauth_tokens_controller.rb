class OauthTokensController < Doorkeeper::TokensController
  def create
    super
    if ( user = resource_owner_from_credentials ) && user.suspended?
      headers.delete 'WWW-Authenticate'
      self.response_body = {
        error: "suspended",
        description: "User has been susppended"
      }.to_json
      self.status = 403
    end
  end
end
