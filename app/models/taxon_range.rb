class TaxonRange < ActiveRecord::Base
  belongs_to :taxon
  belongs_to :source
  
  has_attached_file :range,
    :storage => :s3,
    :s3_credentials => "#{Rails.root}/config/s3.yml",
    :s3_host_alias => INAT_CONFIG['s3_bucket'],
    :bucket => INAT_CONFIG['s3_bucket'],
    :path => "taxon_ranges/:id.:extension",
    :url => ":s3_alias_url"
end
