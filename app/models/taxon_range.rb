class TaxonRange < ActiveRecord::Base
  belongs_to :taxon
  belongs_to :source
  accepts_nested_attributes_for :source
  
  has_attached_file :range,
    :path => ":rails_root/public/attachments/:class/:id.:extension",
    :url => "/attachments/:class/:id.:extension"
    # :storage => :s3,
    # :s3_credentials => "#{Rails.root}/config/s3.yml",
    # :s3_host_alias => INAT_CONFIG['s3_bucket'],
    # :bucket => INAT_CONFIG['s3_bucket'],
    # :path => "taxon_ranges/:id.:extension",
    # :url => ":s3_alias_url"
end
