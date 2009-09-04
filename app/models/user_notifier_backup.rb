# class UserNotifier < ActionMailer::Base
#   def signup_notification(user)
#     setup_email(user)
#   end
#   
#   def forgot_password(user)
#       setup_email(user)
#       @subject    += 'Request to change your password'
#       @body[:url]  = "http://localhost:3000/account/reset_password/#{user.password_reset_code}" 
#     end
# 
#     def reset_password(user)
#       setup_email(user)
#       @subject    += 'Your password has been reset'
#     end
#   
#   protected
#   def setup_email(user)
#     @recipients  = "#{user.email}"
#     @from        = "admin@inaturalist.org"
#     @subject     = "#{user.login}, thanks for signing up at iNaturalist."
#     @sent_on     = Time.now
#     @body[:user] = user
#   end
# end
