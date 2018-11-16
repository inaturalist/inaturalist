class Users::PasswordsController < Devise::PasswordsController
  layout "registrations"
  before_filter :load_registration_form_data
end
