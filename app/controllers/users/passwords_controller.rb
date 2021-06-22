class Users::PasswordsController < Devise::PasswordsController
  layout "registrations"
  before_filter :load_registration_form_data
  before_filter { @skip_external_connections = true }
end
