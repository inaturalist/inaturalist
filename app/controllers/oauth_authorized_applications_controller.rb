class OauthAuthorizedApplicationsController < Doorkeeper::AuthorizedApplicationsController
  # In the doorkeeper parent class there's no `uness` so it just fails for every
  # request that doesn't use CSRF. Since we need to support this via the API
  # with JWT-based auth, we need to skip this check if Devise / Warden have
  # already ok'd the user ~~kueda 20201103
  protect_from_forgery with: :exception, unless: Proc.new {|c| current_user }

  def destroy
    OauthApplication.revoke_tokens_and_grants_for(
      params[:id],
      current_resource_owner
    )

    respond_to do |format|
      format.html do
        redirect_to oauth_authorized_applications_url, notice: I18n.t(
          :notice, scope: %i[doorkeeper flash authorized_applications destroy]
        )
      end

      # The following line has a bug in the original (render vs head) ~~kueda 20201103
      format.json { head :no_content }
    end
  end
end
