# In Rails 5 this initializer can run before the Preference class is loaded from
# the gem, so we need to explicitly load it here before mixing in new stuff
require_dependency "preference"
class Preference
  after_save :touch_owner

  private
  def touch_owner
    owner.touch
  end
end
