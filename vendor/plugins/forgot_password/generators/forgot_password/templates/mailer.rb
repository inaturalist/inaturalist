class <%= class_name %>Mailer < ActionMailer::Base
  
  def forgot_password(password)
    setup_email(password.<%= user_model_name %>)
    @subject    += 'You have requested to change your password'
    @body[:url]  = "http://YOURSITE/change_password/#{password.reset_code}"
  end

  def reset_password(<%= user_model_name %>)
    setup_email(<%= user_model_name %>)
    @subject    += 'Your password has been reset.'
  end

  protected
    def setup_email(<%= user_model_name %>)
      @recipients  = "#{<%= user_model_name %>.email}"
      @from        = "ADMINEMAIL"
      @subject     = "[YOURSITE] "
      @sent_on     = Time.now
      @body[:<%= user_model_name %>] = <%= user_model_name %>
    end
end