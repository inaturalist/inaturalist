class DeviseMailer < Devise::Mailer
  after_action :set_sendgrid_headers
  
  def devise_mail(record, action, opts={})
    user = if record.is_a?(User)
      record
    elsif record.respond_to?(:user)
      record.user
    end
    opts = opts.merge(:subject => t(:welcome_to_inat, :site_name => SITE_NAME)) if action.to_s == "confirmation_instructions"
    if user
      old_locale = I18n.locale
      I18n.locale = user.locale.blank? ? I18n.default_locale : user.locale
      if site = @site || user.site
        opts = opts.merge(
          :from => "#{site.name} <#{site.email_noreply.blank? ? CONFIG.noreply_email : site.email_noreply}>",
          :reply_to => site.email_noreply.blank? ? CONFIG.noreply_email : site.email_noreply
        )
        begin
          DeviseMailer.default_url_options[:host] = URI.parse(site.url).host
        rescue
          # url didn't parse for some reason, leave it as the default
        end
      end
      if action.to_s == "confirmation_instructions"
        if site
          opts = opts.merge(
            :subject => t(:welcome_to_inat, :site_name => site.name)
          )
        else
          # re-translate
          opts = opts.merge(:subject => t(:welcome_to_inat, :site_name => SITE_NAME))
        end
      end
      r = super(record, action, opts)
      I18n.locale = old_locale
      r
    else
      super(record, action, opts)
    end
  end

  private
  def set_sendgrid_headers
    mailer = self.class.name
    headers "X-SMTPAPI" => {
      category:    [ mailer, "#{mailer}##{action_name}" ],
      unique_args: { environment: Rails.env }
    }.to_json
  end
end
