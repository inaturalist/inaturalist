class Preference
  after_save :touch_owner

  private
  def touch_owner
    owner.touch
  end
end
