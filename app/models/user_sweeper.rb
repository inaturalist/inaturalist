# frozen_string_literal: true

class UserSweeper < ActionController::Caching::Sweeper
  begin
    observe User
  rescue ActiveRecord::NoDatabaseError
    puts "Database not connected, failed to observe User. Ignore if setting up for the first time"
  end

  def after_update( user )
    ctrl = ActionController::Base.new
    ctrl.send( :expire_action, UrlHelper.dashboard_updates_url( user_id: user.id, ssl: true ) )
    ctrl.send( :expire_action, UrlHelper.dashboard_updates_url( user_id: user.id, ssl: false ) )
  end
end
