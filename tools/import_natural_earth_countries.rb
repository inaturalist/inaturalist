# Add country places and boundaries from naturalearthdata.org

def system_call(cmd)
  puts "Running #{cmd}"
  system cmd
  puts
end

# CONFIGURE
url = "https://naciscdn.org/naturalearth/50m/cultural/ne_50m_admin_0_countries.zip"
shapefile_name = "ne_50m_admin_0_countries.shp"
test = false
name_column = 'NAME'
place_type = Place::PLACE_TYPE_CODES['Country']
source = Source.find_by_title("Natural Earth Admin 0 - Countries") || Source.create(
  :title => "Natural Earth Admin 0 - Countries",
  :in_text => "Natural Earth #{Date.today.year}",
  :citation => "Natural Earth Admin 0 - Countries. Natural Earth.",
  :url => "https://www.naturalearthdata.com/downloads/50m-cultural-vectors/50m-admin-0-countries-2/"
)
#/ CONFIGURE

# new_shapefile_name = shapefile_name.gsub(/\.shp/, '_longlat.shp')
filename = File.basename(url)
tmp_path = File.join(Dir::tmpdir, "#{File.basename(__FILE__, ".*")}-#{Time.now.to_i}")
archive_path = "#{tmp_path}/#{filename}"
work_path = tmp_path
FileUtils.mkdir_p tmp_path, :mode => 0755

system_call "curl -Lo #{tmp_path}/#{filename} #{url}"
system_call "unzip -d #{tmp_path} #{tmp_path}/#{filename}"

# # Reproject shapefile
# system_call <<-BASH
#   ogr2ogr -t_srs "+proj=longlat +ellps=GRS80 +datum=WGS84 +no_defs" \
#       #{work_path}/#{new_shapefile_name} \
#       #{work_path}/#{shapefile_name}
# BASH

Place.import_from_shapefile("#{work_path}/#{shapefile_name}", 
  name_column: name_column,
  place_type: place_type,
  admin_level: Place::COUNTRY_LEVEL,
  skip_woeid: true,
  test: test,
  source: source
)
