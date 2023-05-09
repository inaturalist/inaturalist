# Add country places and boundaries from naturalearthdata.org

def system_call(cmd)
  puts "Running #{cmd}"
  system cmd
  puts
end

# CONFIGURE
url = "https://www2.census.gov/geo/tiger/TIGER2012/COUNTY/tl_2012_us_county.zip"
shapefile_name = "tl_2012_us_county.shp"
test = false
state_fips = nil
# state_fips = "06" # California
#/ CONFIGURE

filename = File.basename(url)
tmp_path = File.join(Dir::tmpdir, "#{File.basename(__FILE__, ".*")}-#{Time.now.to_i}")
archive_path = "#{tmp_path}/#{filename}"
work_path = tmp_path
FileUtils.mkdir_p tmp_path, :mode => 0755

system_call "curl -Lo #{tmp_path}/#{filename} #{url}"
system_call "unzip -d #{tmp_path} #{tmp_path}/#{filename}"

Place.import_from_shapefile("#{work_path}/#{shapefile_name}", 
  place_type_name: 'County',
  admin_level: Place::COUNTY_LEVEL,
  source: 'census',
  skip_woeid: true,
  test: test
) do |place,shp|
  if state_fips && shp.attributes["STATEFP"] != state_fips
    nil
  else
    place
  end
end
