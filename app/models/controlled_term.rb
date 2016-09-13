#encoding: utf-8
class ControlledTerm < ActiveRecord::Base

  has_many :controlled_term_values, foreign_key: "controlled_attribute_id",
    class_name: "ControlledTermValue", dependent: :destroy
  has_many :values, through: :controlled_term_values, source: :controlled_value
  belongs_to :valid_within_taxon, foreign_key: :valid_within_clade,
    class_name: "Taxon"

  if Rails.env.production?
    has_attached_file :icon,
      storage: :s3,
      s3_credentials: "#{Rails.root}/config/s3.yml",
      s3_host_alias: CONFIG.s3_bucket,
      bucket: CONFIG.s3_bucket,
      path: "controlled_terms/:id-icon.:extension",
      url: ":s3_alias_url",
      default_url: ""
  else
    has_attached_file :icon,
      path: ":rails_root/public/attachments/:class/:id-icon.:extension",
      url: "/attachments/:class/:id-icon.:extension",
      default_url: ""
  end
  validates_attachment_content_type :icon, content_type: [/jpe?g/i, /png/i, /octet-stream/],
    message: "must be JPG or PNG"

  scope :active, -> { where(active: true) }
  scope :attributes, -> { where(is_value: false) }
  scope :values, -> { where(is_value: true) }
  scope :unassigned_values, -> {
    values.
    joins("LEFT JOIN controlled_term_values ctv ON (controlled_terms.id = ctv.controlled_value_id)").
    where("ctv.id IS NULL")
  }
  scope :for_taxon, -> (taxon) {
    joins("LEFT OUTER JOIN taxon_ancestors ta
      ON controlled_terms.valid_within_clade = ta.ancestor_taxon_id").
    where("controlled_terms.valid_within_clade IS NULL OR ta.taxon_id=?", taxon).distinct
  }

end
