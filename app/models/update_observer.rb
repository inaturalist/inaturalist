class UpdateObserver < ActiveRecord::Observer
  observe :update

  def after_save(update)
    ActionController::Base.new.send :expire_action, 
      FakeView.url_for(controller: 'taxa', action: 'updates_count', user_id: update.subscriber_id)
  end
end
