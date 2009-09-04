class UserMailer < ActionMailer::Base
  def signup_notification(user)
    setup_email(user)
    @subject << 'Please activate your new account'
    @body[:url] = "#{APP_CONFIG[:site_url]}/activate/#{user.activation_code}"
  end
  
  def activation(user)
    setup_email(user)
    @subject << 'Your account has been activated!'
    @body[:url] = APP_CONFIG[:site_url]
  end
  
  def admin_password_change(user)
    setup_email(user)
    @subject << "Because of a recent upgrade, your iNaturalist.org password has been reset."
  end
  
  protected
    def setup_email(user)
      @recipients = "#{user.email}"
      @from = "iNaturalist.org <#{APP_CONFIG[:admin_email]}>"
      @subject = "[#{APP_CONFIG[:site_name]}] "
      @sent_on = Time.now
      @body[:user] = user
    end
end
