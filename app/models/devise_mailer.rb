# frozen_string_literal: true

class DeviseMailer < Devise::Mailer
  # NOTE: do not send asm_group_id to Sendgrid from here. We do not want people
  # to be able to unsubscribe from reset password emails
  include Shared::MailerModule
  helper :application

  def devise_mail( record, action, opts = {} )
    set_x_smtpapi_headers_for_action( action )
    user = if record.is_a?( User )
      record
    elsif record.respond_to?( :user )
      record.user
    end
    @site ||= user&.site || Site.default
    if user
      # Remove suppressions that would prevent delivery
      EmailSuppression.destroy_for_email(
        user.email,
        only: [
          # All devise email gets sent with this supression group... but the
          # user needs to receive these. We probably should not send these
          # emails with this group.
          EmailSuppression::ACCOUNT_EMAILS,
          # Receiving server *may* have removed us from their block list
          EmailSuppression::BLOCKS,
          # Sometimes this is due to a non-existent account, but sometimes
          # it's just mysterious
          EmailSuppression::BOUNCES,
          # Receiving server or user may no longer consider us spammers
          EmailSuppression::SPAM_REPORTS,
          # Presumably we only got here because the user wants this email
          EmailSuppression::UNSUBSCRIBES
        ]
      )
      old_locale = I18n.locale
      I18n.locale = user.locale.blank? ? I18n.default_locale : user.locale
      opts = opts.merge(
        from: "#{@site.name} <#{@site.email_noreply}>",
        reply_to: @site.email_noreply
      )
      begin
        DeviseMailer.default_url_options[:host] = URI.parse( @site.url ).host
      rescue StandardError
        # url didn't parse for some reason, leave it as the default
      end
      r = super( record, action, opts )
      I18n.locale = old_locale
      r
    else
      super( record, action, opts )
    end
  end

  def email_changed( record, opts = {} )
    if record.email.blank?
      # Not sure there's anything better we can do here, since we don't have
      # another way of contacting the user except through iNat, and if this
      # is happening against their will then their account is already
      # compromised and we can't reach them through the platform
      Rails.logger.error "Failed to notify #{record} that their email changed because their old email was blank"
      return false
    end
    super( record, opts )
  end

  private

  def set_x_smtpapi_headers_for_action( _action )
    @x_smtpapi_headers = {
      # We're having Sendgrid perform this substitution because ERB freaks out
      # when you put tags like this in a template
      sub: {
        "{{asm_group_unsubscribe_raw_url}}" => ["<%asm_group_unsubscribe_raw_url%>".html_safe]
      }
    }
  end
end
