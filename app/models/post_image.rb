# frozen_string_literal: true

class PostImage < ApplicationRecord
  belongs_to :user, required: true
  belongs_to :post, optional: true

  # Finds PostImage ids in post bodies. Every storage path below contains
  # post_images/:id/, so this matches S3 and local URLs alike.
  BODY_URL_ID = %r{/post_images/(\d+)/}
  STYLES = %i[original large medium small].freeze

  # Uploads start unclaimed (post_id NULL) until a post that uses them is
  # saved; ones never claimed are deleted by
  # inaturalist:delete_orphaned_post_images
  scope :orphaned, -> { where( post_id: nil ).where( "created_at < ?", 24.hours.ago ) }

  FILE_OPTIONS = {
    styles: proc {| attachment |
      fmt = { "image/gif" => :gif, "image/png" => :png, "image/webp" => :webp }.
        fetch( attachment.instance.file_content_type, :jpg )
      {
        original: { geometry: "2048x2048>", format: fmt, processors: [:thumbnail, :metadata_filter] },
        large: { geometry: "1024x1024>", format: fmt, processors: [:thumbnail, :metadata_filter] },
        medium: { geometry: "500x500>", format: fmt, processors: [:thumbnail, :metadata_filter] },
        small: { geometry: "240x240>", format: fmt, processors: [:deanimator, :metadata_filter] }
      }
    }
  }.freeze

  if CONFIG.usingS3
    has_attached_file :file, FILE_OPTIONS.merge(
      storage: :s3,
      s3_credentials: "#{Rails.root}/config/s3.yml",
      s3_protocol: CONFIG.s3_protocol || "https",
      s3_host_alias: CONFIG.s3_host || CONFIG.s3_bucket,
      s3_region: CONFIG.s3_region,
      bucket: CONFIG.s3_bucket,
      path: "post_images/:id/:style.:content_type_extension",
      url: ":s3_alias_url"
    )
    invalidate_cloudfront_caches :file, "post_images/:id/*"
  else
    has_attached_file :file, FILE_OPTIONS.merge(
      path: ":rails_root/public/attachments/post_images/:id/:style.:content_type_extension",
      url: "/attachments/post_images/:id/:style.:content_type_extension"
    )
  end

  validates_attachment :file,
    presence: true,
    content_type: { content_type: %w(image/jpeg image/png image/gif image/webp) },
    size: { less_than_or_equal_to: 20.megabytes }
  validate :alt_kept_on_published_cover

  # Must follow has_attached_file, which defines the post_process callbacks
  after_post_process :set_dimensions

  def absolute_url( style )
    url = file.url( style, timestamp: false )
    return url if url =~ %r{\Ahttps?://}

    UrlHelper.uri_join( UrlHelper.root_url, url )
  end

  def upload_json
    {
      id: id,
      width: width,
      height: height,
      caption: caption,
      attribution: attribution,
      alt: alt
    }.merge( STYLES.to_h {| style | [:"#{style}_url", absolute_url( style )] } )
  end

  private

  # Stores the large style's dimensions, since that's the src of body images
  def set_dimensions
    large = file.queued_for_write[:large]
    return unless large

    self.width, self.height = FastImage.size( large.path )
  end

  # Publishing requires alt text on the cover, so clearing it here would make
  # every later save of the post fail
  def alt_kept_on_published_cover
    return unless persisted? && will_save_change_to_alt? && alt.blank?
    return unless Post.published.where( cover_image_id: id ).exists?

    errors.add( :alt, :required_for_published_cover )
  end
end
