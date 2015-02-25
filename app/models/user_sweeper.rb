class UserSweeper < ActionController::Caching::Sweeper
  observe User

  def after_update(user)
    ctrl = ActionController::Base.new
    Site.limit(100).each do |s|
      ctrl.expire_fragment(User.header_cache_key_for(user, site: s))
    end
  end
end
