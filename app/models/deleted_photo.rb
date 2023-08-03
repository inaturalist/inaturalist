class DeletedPhoto < ApplicationRecord
  belongs_to :user
  belongs_to :photo
  scope :still_in_s3, ->{ where(removed_from_s3: false) }

  def remove_from_s3( options = { } )
    return if removed_from_s3?
    if orphan?
      return if created_at > 1.month.ago
    else
      return if created_at > 6.month.ago
    end
    # do not remove from S3 if the DeletedPhoto is still associated to a Photo 
    # (for example after resurrect)
    return if photo?
    client = options[:s3_client] || LocalPhoto.new.s3_client
    static_bucket = LocalPhoto.s3_bucket( false )

    s3_objects = nil
    images = nil
    found_in_odp_bucket = false
    # first check to see if the photo has files in the ODP bucket
    if LocalPhoto.odp_s3_bucket_enabled?
      odp_bucket = LocalPhoto.s3_bucket( true )
      s3_objects = client.list_objects( bucket: odp_bucket, prefix: "photos/#{ photo_id }/" )
      images = s3_objects.contents
      found_in_odp_bucket = true unless images.blank?
    end

    # if there are no ODP files, check the static bucket
    if images.blank?
      s3_objects = client.list_objects( bucket: static_bucket, prefix: "photos/#{ photo_id }/" )
      images = s3_objects.contents
    end

    # there were files in either bucket
    if s3_objects && s3_objects.data && s3_objects.data.is_a?( Aws::S3::Types::ListObjectsOutput )
      if images.any?
        if found_in_odp_bucket
          # the photo has files in the OBP bucket, so delete them
          odp_bucket = LocalPhoto.s3_bucket( true )
          puts "deleting photo #{photo_id} [#{images.size} files] from S3 ODP"
          client.delete_objects( bucket: odp_bucket, delete: { objects: images.map{|s| { key: s.key } } } )
        end
        # the photo has files in either bucket, so attempt a delete from the static bucket
        puts "deleting photo #{photo_id} [#{images.size} files] from S3"
        client.delete_objects( bucket: static_bucket, delete: { objects: images.map{|s| { key: s.key } } } )
        update( removed_from_s3: true )
      else
        # the file list is for some reason empty
        update( removed_from_s3: true )
        puts "#{photo_id} has no photos in S3"
      end
    end
  end

end
