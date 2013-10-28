class DeviseMailer < Devise::Mailer
  def headers_for(action, opts)
    opts[:subject] = t(:welcome_to_inat, :site_name => SITE_NAME) if action == :confirmation_instructions
    super(action, opts)
  end

  def devise_mail(record, action, opts={})
    user = if record.is_a?(User)
      record
    elsif record.respond_to?(:user)
      record.user
    end
    if user
      I18n.locale = user.locale.blank? ? I18n.default_locale : user.locale
    end
    super(record, action, opts)
  end
end
