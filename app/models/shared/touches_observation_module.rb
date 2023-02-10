module Shared::TouchesObservationModule
  def self.included(base)
    base.after_save :touch_observation
    base.after_destroy :touch_observation
    base.attr_accessor :wait_for_obs_index_refresh
  end

  def touch_observation
    return unless observation
    return if observation.bulk_delete
    return if observation.id_previously_changed?
    if respond_to?(:wait_for_obs_index_refresh) && wait_for_obs_index_refresh
      observation.wait_for_index_refresh = true
    end
    observation.touch
  end

end
