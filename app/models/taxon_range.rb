class TaxonRange < ActiveRecord::Base
  
  belongs_to :taxon
  belongs_to :source
  has_many :listed_taxa, :dependent => :nullify
  
  accepts_nested_attributes_for :source
  
  scope :without_geom, -> { select((column_names - ['geom']).join(', ')) }
  scope :simplified, -> { select(<<-SQL
      id, taxon_id, 
      st_multi(
        cleangeometry(
          ST_Buffer(
            ST_SimplifyPreserveTopology(geom, 
              exp(-(log(5000/st_npoints(geom)::float)+1.5944)/0.2586)
            ),
            0.0
          )
        )
      ) AS geom
    SQL
  ) }
  
  has_attached_file :range,
    :path => ":rails_root/public/attachments/:class/:id.:extension",
    :url => "#{ CONFIG.attachments_host }/attachments/:class/:id.:extension"
    # :storage => :s3,
    # :s3_credentials => "#{Rails.root}/config/s3.yml",
    # :s3_host_alias => CONFIG.s3_bucket,
    # :bucket => CONFIG.s3_bucket,
    # :path => "taxon_ranges/:id.:extension",
    # :url => ":s3_alias_url"
  
  def validate_geometry
    if geom && geom.num_points < 3
      errors.add(:geom, " must have more than 2 points")
    end
  end

  def kml_url
    return "#{range.url}" unless range.blank?
    return url if url =~ /kml/
    nil
  end
  
  def create_kml_attachment
    return unless geom
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.kml('xmlns' => 'http://earth.google.com/kml/2.1') do
        xml.Document {
          xml.Placemark {
            xml.name
            xml.description
            xml.styleUrl "#{CONFIG.site_url}/assets/index.kml#taxon_range"
            xml << self.geom.as_kml
          }
        }
      end
    end
    tmp_path = File.join(Dir::tmpdir, "temp.kml")
    f = File.open(tmp_path, "w")
    f.write(builder.to_xml)
    f.close
    file = File.open(tmp_path, "r")
    self.range = file
    self.save
  end
  
  def create_geom_from_kml_attachment
    return unless File.exists?(self.range.path)
    tmp_path = File.join(Dir::tmpdir, "#{self.id}_#{Time::now.seconds_since_midnight.round}.geojson")
    cmd = "ogr2ogr -f GeoJSON #{tmp_path} #{self.range.path}"
    system cmd
    open(tmp_path) do |f|
      if geojsongeom = GeoRuby::SimpleFeatures::Geometry.from_geojson(f.read)
        self.geom = geojsongeom.features.first.geometry
        if !self.geom.is_a?(MultiPolygon)
          if self.geom.is_a?(Polygon)
            self.geom = MultiPolygon.from_polygons([self.geom])
          else
            next
          end
        end
        self.save
      end
      f.close
    end
    File.delete(tmp_path)
  end

  def bounds
    return @bounds if @bounds
    result = TaxonRange.where(id: id).select("
      ST_YMIN(geom) min_y, ST_YMAX(geom) max_y,
      ST_XMIN(geom) min_x, ST_XMAX(geom) max_x").first
    @bounds = {
      min_x: [result.min_x.to_f, -179.9].max,
      min_y: [result.min_y.to_f, -89.9].max,
      max_x: [result.max_x.to_f, 179.9].min,
      max_y: [result.max_y.to_f, 89.9].min
    }
  end

end
