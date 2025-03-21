# frozen_string_literal: true

class DeletedPhoto < ApplicationRecord
  belongs_to :user
  belongs_to :photo
  scope :still_in_s3, -> { where( removed_from_s3: false ) }

  def eligible_for_removal?
    return false if removed_from_s3?

    if orphan?
      return false if created_at > 1.month.ago
    else
      latest_moderator_action = ModeratorAction.where(
        resource_type: ["Photo", "LocalPhoto"],
        resource_id: photo_id
      ).order( id: :desc ).first
      if latest_moderator_action&.action == ModeratorAction::HIDE &&
          latest_moderator_action&.private?
        return false if created_at > ModeratorAction::PRIVATE_MEDIA_RETENTION_TIME.ago
      elsif created_at > 6.month.ago
        return false
      end
    end
    # do not remove from S3 if the DeletedPhoto is still associated to a Photo
    # (for example after resurrect)
    return false if photo

    true
  end

  def remove_from_s3( options = {} )
    return unless eligible_for_removal?

    client = options[:s3_client] || LocalPhoto.new.s3_client
    static_bucket = LocalPhoto.s3_bucket( false )

    s3_objects = nil
    images = nil
    found_in_odp_bucket = false
    # first check to see if the photo has files in the ODP bucket
    if LocalPhoto.odp_s3_bucket_enabled?
      odp_bucket = LocalPhoto.s3_bucket( true )
      s3_objects = client.list_objects( bucket: odp_bucket, prefix: "photos/#{photo_id}/" )
      images = s3_objects.contents
      found_in_odp_bucket = true unless images.blank?
    end

    # if there are no ODP files, check the static bucket
    if images.blank?
      s3_objects = client.list_objects( bucket: static_bucket, prefix: "photos/#{photo_id}/" )
      images = s3_objects.contents
    end

    # there were files in either bucket
    return unless s3_objects&.data.is_a?( Aws::S3::Types::ListObjectsOutput )

    if images.any?
      if found_in_odp_bucket
        # the photo has files in the OBP bucket, so delete them
        odp_bucket = LocalPhoto.s3_bucket( true )
        puts "deleting photo #{photo_id} [#{images.size} files] from S3 ODP"
        client.delete_objects( bucket: odp_bucket, delete: { objects: images.map {| s | { key: s.key } } } )
      end
      # the photo has files in either bucket, so attempt a delete from the static bucket
      puts "deleting photo #{photo_id} [#{images.size} files] from S3"
      client.delete_objects( bucket: static_bucket, delete: { objects: images.map {| s | { key: s.key } } } )
      update( removed_from_s3: true )
    else
      # the file list is for some reason empty
      update( removed_from_s3: true )
      puts "#{photo_id} has no photos in S3"
    end
  end

  def self.remove_from_s3_batch( min_id, max_id )
    client = LocalPhoto.new.s3_client
    DeletedPhoto.still_in_s3.
      where( "id >= ?", min_id ).
      where( "id < ?", max_id ).
      includes( :photo ).
      find_each( batch_size: 1000 ) do | dp |
      dp.remove_from_s3( s3_client: client )
    end
  end
end
