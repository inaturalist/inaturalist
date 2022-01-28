# frozen_string_literal: true

module Users
  class ConfirmationsController < Devise::ConfirmationsController
    layout "registrations"
    before_action :load_registration_form_data
    # This is supposed to indicate to the view that it should not be
    # establishing connections to other domains, e.g. by loading remote
    # assets, in order to prevent those domains to getting access to
    # semi-secret information in a URL's querystring, e.g. a confirmation
    # token
    before_action { @skip_external_connections = true }
    skip_before_action :verify_authenticity_token
    before_action :return_here, only: []

    def show
      Rails.logger.debug "[DEBUG] @observations: #{@observations}"
      super
    end
  end
end
