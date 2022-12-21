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
  end
end
