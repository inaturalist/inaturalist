class UserSweeper < ActionController::Caching::Sweeper
  observe User

  def after_update( user )
    ctrl = ActionController::Base.new
    Site.limit( 100 ).each do |s|
      ctrl.expire_fragment( User.header_cache_key_for( user, site: s ) )
    end
    ctrl.expire_fragment( User.header_cache_key_for( user, site: nil ) )
    ctrl.send :expire_action, FakeView.home_url( user_id: user.id, ssl: true )
    ctrl.send :expire_action, FakeView.home_url( user_id: user.id, ssl: false )
  end
end
