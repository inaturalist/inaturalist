# frozen_string_literal: true

class PostImage < ApplicationRecord
  belongs_to :user
  belongs_to :post, optional: true

  FILE_OPTIONS = {
    styles: proc {| attachment |
      fmt = ( attachment.instance.file_content_type == "image/gif" ) ? :gif : :jpg
      {
        original: { geometry: "2048x2048>", format: fmt, processors: [:thumbnail, :metadata_filter] },
        large: { geometry: "1024x1024>", format: fmt },
        medium: { geometry: "500x500>", format: fmt },
        small: { geometry: "240x240>", format: fmt, processors: [:deanimator] }
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
      path: ":rails_root/public/attachments/:class/:attachment/:id/:style.:content_type_extension",
      url: "/attachments/:class/:attachment/:id/:style.:content_type_extension"
    )
  end

  validates_attachment :file,
    presence: true,
    content_type: { content_type: %w(image/jpeg image/png image/gif image/webp) },
    size: { less_than_or_equal_to: 20.megabytes }
end
