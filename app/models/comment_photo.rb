# frozen_string_literal: true

# Join between a Comment and a Photo embedded in its body, mirroring
# ObservationPhoto. Unlike ObservationPhoto the parent (comment) does not exist
# yet when the row is created: the photo is uploaded and this join is created
# the moment it is dropped into the editor, then Comment#sync_comment_photos
# links it once the comment is saved with the photo's URL in its body.
class CommentPhoto < ApplicationRecord
  # How long an unlinked (drafted-but-unsubmitted) row survives before the
  # delete_expired_comment_photos sweeper reaps it and its orphaned photo.
  DRAFT_TTL = 1.hour

  belongs_to :comment, optional: true, inverse_of: :comment_photos
  belongs_to :photo
  belongs_to :user

  validates :photo, presence: true
  validates :user, presence: true
  # One join per photo per comment; also dedupes a photo dropped twice while
  # still unlinked (comment_id IS NULL).
  validates_uniqueness_of :photo_id, scope: :comment_id
  validate :commenter_owns_photo

  after_destroy :destroy_orphan_photo

  def destroy_orphan_photo
    Photo.delay( priority: INTEGRITY_PRIORITY ).destroy_orphans( photo_id )
    true
  end

  def commenter_owns_photo
    return unless photo
    return if user_id == photo.user_id

    errors.add( :photo, "must be owned by the commenter" )
  end
end
