module Shared::TouchesObservationModule
  def self.included(base)
    base.after_create  :touch_observation
    base.after_destroy :touch_observation
  end

  def touch_observation
    return unless observation
    return if observation.bulk_delete
    observation.touch
  end

end
