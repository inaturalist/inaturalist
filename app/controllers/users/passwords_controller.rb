# frozen_string_literal: true

module Users
  class PasswordsController < Devise::PasswordsController
    include Shared::FiltersModule

    layout "registrations"

    prepend_before_action :set_request_locale
    before_action :load_registration_form_data

    # This is supposed to indicate to the view that it should not be
    # establishing connections to other domains, e.g. by loading remote
    # assets, in order to prevent those domains to getting access to
    # semi-secret information in a URL's querystring, e.g. a password reset
    # token
    before_action { @skip_external_connections = true }

    skip_before_action :verify_authenticity_token

    def update
      super do | user |
        if resource.errors.empty? && !user.confirmed?
          # If a user successfully reset their password, that means they
          # received an email and clicked a link with a valid password reset
          # token, which is the same as confirming that they have access to
          # their email account
          user.confirm
        end
      end
    end

    # The following fixes a bug in Seek where the reset password form won't
    # submit if the client passes an Authorization header, but i'm still not
    # sure if https://github.com/inaturalist/inaturalist/pull/3280 contains a
    # better fix

    protected

    # Overriding the method from Devise
    def require_no_authentication
      require_no_authentication_or_app_jwt
    end

    # Copy of the Devise equivalent except it checks if the
    # authenticated "user" is an anonymous user resulting from application
    # authentication. We should remove this if/when we build out
    # https://github.com/inaturalist/iNaturalistAPI/issues/378
    def require_no_authentication_or_app_jwt
      assert_is_devise_resource!
      return unless is_navigational_format?

      no_input = devise_mapping.no_input_strategies

      authenticated = if no_input.present?
        args = no_input.dup.push scope: resource_name
        warden.authenticate?( *args )
      else
        warden.authenticated?( resource_name )
      end

      if authenticated &&
          ( resource = warden.user( resource_name ) ) &&
          # This is the only different bit
          !resource&.anonymous?
        set_flash_message( :alert, "already_authenticated", scope: "devise.failure" )
        redirect_to after_sign_in_path_for( resource )
      end
    end
  end
end
