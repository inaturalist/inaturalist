# frozen_string_literal: true

class DeletedSound < ApplicationRecord
  belongs_to :user
  belongs_to :sound
  scope :still_in_s3, -> { where( removed_from_s3: false ) }

  def eligible_for_removal?
    return false if removed_from_s3?

    if orphan?
      return false if created_at > 1.month.ago
    else
      latest_moderator_action = ModeratorAction.where(
        resource_type: ["Sound", "LocalSound"],
        resource_id: sound_id
      ).order( id: :desc ).first
      if latest_moderator_action&.action == ModeratorAction::HIDE &&
          latest_moderator_action&.private?
        return false if created_at > ModeratorAction::PRIVATE_MEDIA_RETENTION_TIME.ago
      elsif created_at > 6.month.ago
        return false
      end
    end
    # do not remove from S3 if the DeletedSound is still associated to a Sound
    # (for example after resurrect)
    return false if sound

    true
  end

  def remove_from_s3( options = {} )
    return unless eligible_for_removal?

    client = options[:s3_client] || LocalPhoto.new.s3_client
    sounds = client.list_objects( bucket: CONFIG.s3_bucket, prefix: "sounds/#{sound_id}." ).contents
    if sounds.any?
      puts "deleting sound #{sound_id} [#{sounds.size} files] from S3"
      client.delete_objects( bucket: CONFIG.s3_bucket, delete: { objects: sounds.map {| s | { key: s.key } } } )
      update( removed_from_s3: true )
    else
      update( removed_from_s3: true )
      puts "#{sound_id} has no sounds in S3"
    end
  end
end
