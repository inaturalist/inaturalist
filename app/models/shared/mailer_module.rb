# frozen_string_literal: true

module Shared
  module MailerModule
    def self.included( base )
      base.after_action :set_sendgrid_headers
      base.after_action :check_allowed_email_recipient_patterns
    end

    private

    def default_url_options
      opts = ( Rails.application.config.action_mailer.default_url_options || {} ).dup
      site = @user&.site || @site || Site.default
      if ( site_uri = URI.parse( site.url ) )
        # || site.url is kind of a fallback to deal with testing where the
        # default uri is test.host, which URI.parse doesn't parse a host from.
        # It might cause problems elsewhere if a site has a bad url property
        opts[:host] = site_uri.host || site.url
        if ( port = site_uri.port ) && ![80, 443].include?( port )
          opts[:port] = port
        end
      end
      opts
    end

    def set_sendgrid_headers
      return if message.blank? || message.to.blank?

      mailer = self.class.name
      headers "X-SMTPAPI" => {
        to: message.to,
        category: [mailer, "#{mailer}##{action_name}"],
        unique_args: { environment: Rails.env }
      }.merge( @x_smtpapi_headers || {} ).to_json
    end

    # Check for an array of allowed email patterns in config/config.yml to
    # control email delivery in certain environments
    def check_allowed_email_recipient_patterns
      return unless message && CONFIG&.allowed_email_recipient_patterns

      message.to_addresses.each do | email_address |
        unless CONFIG.allowed_email_recipient_patterns.detect {| pattern | email_address.to_s =~ /#{pattern}/ }
          message.perform_deliveries = false
          break
        end
      end
    end
  end
end
