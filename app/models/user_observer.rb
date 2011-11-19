class UserObserver < ActiveRecord::Observer
  def after_create(user)
    user.reload
    if !user.email.blank? && user.pending?
      UserMailer.deliver_signup_notification(user)
    end
  end
  def after_save(user)
    user.reload
    UserMailer.deliver_activation(user) if (user.recently_activated? && !user.email.blank?)
  end
end
