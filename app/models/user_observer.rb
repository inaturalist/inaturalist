class UserObserver < ActiveRecord::Observer
  def after_create(user)
    if !user.email.blank? && user.pending? && !user.skip_registration_email
      UserMailer.deliver_signup_notification(user)
    end
  end
  
  def after_save(user)
    UserMailer.deliver_activation(user) if (user.recently_activated? && !user.email.blank?)
  end
end
