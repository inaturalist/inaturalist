class TaxonRange < ActiveRecord::Base
  belongs_to :taxon
  belongs_to :source
  has_many :listed_taxa, :dependent => :nullify
  
  accepts_nested_attributes_for :source
  
  scope :without_geom, select((column_names - ['geom']).join(', '))
  scope :simplified, select(<<-SQL
      id, taxon_id, 
      multi(cleangeometry(
        ST_SimplifyPreserveTopology(geom, 
          exp(-(log(5000/npoints(geom)::float)+1.5944)/0.2586)
        )
      )) AS geom
    SQL
  )
  
  has_attached_file :range,
    :path => ":rails_root/public/attachments/:class/:id.:extension",
    :url => "/attachments/:class/:id.:extension"
    # :storage => :s3,
    # :s3_credentials => "#{Rails.root}/config/s3.yml",
    # :s3_host_alias => CONFIG.get(:s3_bucket),
    # :bucket => CONFIG.get(:s3_bucket),
    # :path => "taxon_ranges/:id.:extension",
    # :url => ":s3_alias_url"
  
  def validate_geometry
    if geom && geom.num_points < 3
      errors.add(:geom, " must have more than 2 points")
    end
  end
end
