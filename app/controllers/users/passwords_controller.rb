# frozen_string_literal: true

module Users
  class PasswordsController < Devise::PasswordsController
    layout "registrations"
    before_action :load_registration_form_data
    before_action { @skip_external_connections = true }
    skip_before_action :verify_authenticity_token
  end
end
