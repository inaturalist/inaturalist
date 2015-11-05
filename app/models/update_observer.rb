class UpdateObserver < ActiveRecord::Observer
  observe :update

  def after_save(update)
    ActionController::Base.new.send(:expire_action,
      FakeView.updates_count_path(user_id: update.subscriber_id))
  end
end
