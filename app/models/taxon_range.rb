class TaxonRange < ActiveRecord::Base
  belongs_to :taxon
  belongs_to :source
  has_many :listed_taxa
  
  accepts_nested_attributes_for :source
  
  named_scope :without_geom, {:select => (column_names - ['geom']).join(', ')}
  named_scope :simplified, {
    :select => <<-SQL
      id, taxon_id, 
      multi(cleangeometry(
        ST_SimplifyPreserveTopology(geom, 
          CASE 
          WHEN npoints(geom) > 9000 THEN 0.1
          WHEN npoints(geom) > 1000 THEN 0.05
          ELSE 0.01 END))) AS geom
    SQL
  }
  
  has_attached_file :range,
    :path => ":rails_root/public/attachments/:class/:id.:extension",
    :url => "/attachments/:class/:id.:extension"
    # :storage => :s3,
    # :s3_credentials => "#{Rails.root}/config/s3.yml",
    # :s3_host_alias => INAT_CONFIG['s3_bucket'],
    # :bucket => INAT_CONFIG['s3_bucket'],
    # :path => "taxon_ranges/:id.:extension",
    # :url => ":s3_alias_url"
  
  def validate_geometry
    if geom && geom.num_points < 3
      errors.add(:geom, " must have more than 2 points")
    end
  end
end
