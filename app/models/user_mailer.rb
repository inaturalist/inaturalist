class UserMailer < ActionMailer::Base
  def signup_notification(user)
    setup_email(user)
    @subject << 'Please activate your new account'
    @body[:url] = "#{CONFIG.site_url}/activate/#{user.activation_code}"
  end
  
  def activation(user)
    setup_email(user)
    @subject << 'Your account has been activated!'
  end
  
  def admin_password_change(user)
    setup_email(user)
    @subject << "Because of a recent upgrade, your #{CONFIG.site_name} password has been reset."
  end

  # Send the user an email saying the bulk observation import encountered
  # an error.
  def bulk_observation_error(user, observation_file, error_details)
    setup_email(user)
    @subject << "We're sorry but your bulk import of #{observation_file} has failed."

    @message       = error_details[:reason]
    @errors        = error_details[:errors]
    @field_options = error_details[:field_options]

    mail(:to => "#{user.name} <#{user.email}>", :subject => @subject, :from => @from)
  end

  # Send the user an email saying the bulk observation import was successful.
  def bulk_observation_success(user, observation_file)
    setup_email(user)
    @subject << "The bulk import of #{observation_file} has been completed successfully."
    @filename = observation_file
    mail(:to => "#{user.name} <#{user.email}>", :subject => @subject, :from => @from)
  end

  protected
    def setup_email(user)
      @recipients = "#{user.email}"
      # TODO: restore the display name after they fix this bug: https://rails.lighthouseapp.com/projects/8994/tickets/2340
      # @from = "#{CONFIG.site_name} <#{CONFIG.noreply_email}>"
      @from = CONFIG.noreply_email
      @reply_to = CONFIG.noreply_email
      @subject = "[#{CONFIG.site_name}] "
      @sent_on = Time.now
      @user = user
    end
end
