# frozen_string_literal: true

class ControlledTermLabel < ApplicationRecord
  belongs_to :controlled_term
  belongs_to :valid_within_taxon, foreign_key: :valid_within_clade,
    class_name: "Taxon"

  validates :label, presence: true, on: :create
  validates :definition, presence: true, on: :create

  if CONFIG.usingS3
    has_attached_file :icon,
      storage: :s3,
      s3_credentials: "#{Rails.root}/config/s3.yml",
      s3_protocol: CONFIG.s3_protocol || "https",
      s3_host_alias: CONFIG.s3_host || CONFIG.s3_bucket,
      s3_region: CONFIG.s3_region,
      bucket: CONFIG.s3_bucket,
      path: "controlled_terms/:id-icon.:extension",
      url: ":s3_alias_url",
      default_url: ""
    invalidate_cloudfront_caches :icon, "controlled_terms/:id-icon.*"
  else
    has_attached_file :icon,
      path: ":rails_root/public/attachments/:class/:id-icon.:extension",
      url: "/attachments/:class/:id-icon.:extension",
      default_url: ""
  end
  validates_attachment_content_type :icon, content_type: [/jpe?g/i, /png/i, /octet-stream/],
    message: "must be JPG or PNG"
end
