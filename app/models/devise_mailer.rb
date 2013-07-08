class DeviseMailer < Devise::Mailer
  def headers_for(action, opts)
    opts[:subject] = t(:welcome_to_inat, :site_name => SITE_NAME) if action == :confirmation_instructions
    super(action, opts)
  end
end
