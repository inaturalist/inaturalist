# frozen_string_literal: true

module Users
  class ConfirmationsController < Devise::ConfirmationsController
    include Users::CustomDeviseModule

    before_action :load_registration_form_data

    # This is supposed to indicate to the view that it should not be
    # establishing connections to other domains, e.g. by loading remote
    # assets, in order to prevent those domains to getting access to
    # semi-secret information in a URL's querystring, e.g. a confirmation
    # token
    before_action { @skip_external_connections = true }

    skip_before_action :verify_authenticity_token

    # You should never automatically return to the confirmation views
    before_action :return_here, only: []

    before_action do
      # If the user is already confirmed and they're not clicking a
      # confirmation link to confirm a change to their email address, don't
      # show them any confirmation UI b/c there's nothing for them to do
      if current_user&.confirmed? && !current_user.unconfirmed_email?
        set_flash_message :notice, :confirmed if is_navigational_format?
        redirect_to dashboard_path
      end
    end

    def after_confirmation_path_for( resource_name, _resource )
      if signed_in?( resource_name )
        home_path( confirmed: true )
      else
        new_session_path( resource_name, confirmed: true )
      end
    end
  end
end
