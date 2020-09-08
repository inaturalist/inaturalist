class DeviseMailer < Devise::Mailer
  # Note: do not send asm_group_id to Sendgrid from here. We do not want people
  # to be able to unsubscribe from reset password emails
  include Shared::MailerModule
  
  def devise_mail( record, action, opts={ } )
    set_x_smtpapi_headers_for_action( action )
    user = if record.is_a?( User )
      record
    elsif record.respond_to?( :user )
      record.user
    end
    site = @site || user.try( :site ) || Site.default
    if user
      old_locale = I18n.locale
      I18n.locale = user.locale.blank? ? I18n.default_locale : user.locale
      opts = opts.merge(
        from: "#{site.name} <#{site.email_noreply}>",
        reply_to: site.email_noreply
      )
      if action.to_s == "confirmation_instructions"
        return false unless user.active_for_authentication?
        opts = opts.merge( subject: t( :welcome_to_inat, site_name: site.name ) )
      end
      begin
        DeviseMailer.default_url_options[:host] = URI.parse(site.url).host
      rescue
        # url didn't parse for some reason, leave it as the default
      end
      r = super( record, action, opts )
      I18n.locale = old_locale
      r
    else
      super( record, action, opts )
    end
  end

  private
  def set_x_smtpapi_headers_for_action( action )
    asm_group_id = nil
    if CONFIG.sendgrid && CONFIG.sendgrid.asm_group_ids
      asm_group_id = if action.to_s == "confirmation_instructions"
        # Treat the initial welcome email as a default "transactional" email
        # like the daily updates so that when people click the unsubscribe link,
        # they don't unsubscribe from password reset emails
        CONFIG.sendgrid.asm_group_ids.default
      else
        # The "account" unsubscribe group should apply to all other devise
        # emails, like password resets
        CONFIG.sendgrid.asm_group_ids.account
      end
    end
    @x_smtpapi_headers = {
      # This is an identifier specifying the Sendgrid Unsubscribe Group this
      # email belongs to. This assumes we're using one for all email sent from
      # the webapp
      asm_group_id: asm_group_id,
      # We're having Sendgrid perform this substitution because ERB freaks out
      # when you put tags like this in a template
      sub: {
        "{{asm_group_unsubscribe_raw_url}}" => ['<%asm_group_unsubscribe_raw_url%>'.html_safe]
      }
    }
  end

end
