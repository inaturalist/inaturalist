class PasswordMailer < ActionMailer::Base
  
  def forgot_password(password)
    setup_email(password.user)
    site = password.user.site || Site.default
    @subject  += "Link to change your #{site.name} password."
    @body[:url] = "#{site.url}/change_password/#{password.reset_code}"
  end

  def reset_password(user)
    setup_email(user)
    site = user.site || Site.default
    @subject += "Your #{site.site_name} password has been reset."
  end

  protected
    def setup_email(user)
      site = user.site || Site.default
      @recipients = "#{user.email}"
      @from = site.email_noreply
      @subject = "[#{site.name}] "
      @sent_on = Time.now
      @body[:user] = user
    end
end