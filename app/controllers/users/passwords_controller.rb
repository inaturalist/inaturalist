class Users::PasswordsController < Devise::PasswordsController
  layout "registrations"
  before_action :load_registration_form_data
  before_action { @skip_external_connections = true }
end
