class ObservationPhoto < ActiveRecord::Base
  belongs_to_with_uuid :observation, inverse_of: :observation_photos, counter_cache: false
  belongs_to :photo

  validates :photo, presence: true
  validates :observation, presence: true
  validates_associated :photo
  validates_uniqueness_of :photo_id, scope: :observation_id
  validate :observer_owns_photo
  
  after_commit :set_observation_quality_grade,
               :set_observation_photos_count,
               on: :create
  after_destroy :destroy_orphan_photo, :set_observation_quality_grade,
    :set_observation_photos_count, :log_destruction

  include Shared::TouchesObservationModule
  include ActsAsUUIDable

  def to_s
    "<ObservationPhoto #{id} observation_id: #{observation_id} photo_id: #{photo_id}>"
  end
  
  def destroy_orphan_photo
    Photo.delay(:priority => INTEGRITY_PRIORITY).destroy_orphans(photo_id)
    true
  end
  
  def set_observation_quality_grade
    return true unless observation
    return true if observation.bulk_delete
    return true if observation.new_record? # presumably this will happen when the obs is saved
    # For some reason the observation's after_commit callbacks seem to fire
    # after the ObservationPhoto is saved, so if you don't set the quality_grade
    # on this instance of the observation, it will fail to index properly
    observation.quality_grade = Observation.set_quality_grade( observation.id )
    true
  end

  def set_observation_photos_count
    return true unless observation_id
    return true if observation.bulk_delete
    Observation.where(id: observation_id).update_all(
      observation_photos_count: ObservationPhoto.where(:observation_id => observation_id).count)
    true
  end

  # Temporary logging while we try to figure out a disappearing photos bug
  def log_destruction
    msg = "ObservationPhoto #{id} destroyed. user_id: #{observation.user_id}, observation_id: #{observation_id}, photo_id: #{photo_id}"
    Rails.logger.debug "[INFO #{Time.now}] #{msg}"
    Logstasher.write_hash(
      # last_error is a text field, while error_message is a keyword field, so
      # if we want to search on text in the message, we need to use last_error
      # (or arguments, or backtrace)
      last_error: msg,
      backtrace: caller( 0 ).select{|l| l.index( Rails.root.to_s )}.map{|l| l.sub( Rails.root.to_s, "" )}.join( "\n" ),
      subtype: "ObservationPhoto#destroy",
      model: "ObservationPhoto",
      model_method: "destroy",
      model_method_id: "ObservationPhoto::destroy::#{id}"
    )
    true
  end

  def observer_owns_photo
    return unless observation && photo
    unless observation.user_id == photo.user_id
      errors.add(:photo, "must be owned by the observer" )
    end
  end

end
