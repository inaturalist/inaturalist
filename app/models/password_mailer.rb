class PasswordMailer < ActionMailer::Base
  
  def forgot_password(password)
    setup_email(password.user)
    @subject    += "Link to change your #{CONFIG.get(:site_name)} password."
    @body[:url]  = "#{CONFIG.get(:site_url)}/change_password/#{password.reset_code}"
  end

  def reset_password(user)
    setup_email(user)
    @subject    += "Your #{CONFIG.get(:site_name)} password has been reset."
  end

  protected
    def setup_email(user)
      @recipients  = "#{user.email}"
      @from        = CONFIG.get(:noreply_email)
      @subject     = "[#{CONFIG.get(:site_name)}] "
      @sent_on     = Time.now
      @body[:user] = user
    end
end