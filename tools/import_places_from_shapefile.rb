require 'rubygems'
require 'trollop'

ThinkingSphinx::Deltas.suspend!

@opts = Trollop::options do
    banner <<-EOS
Import shapefile polygons as new Places. The shapefile can be a path to a
local .shp file or a URL to a remote ZIP file containing a shapefile. If the
latter, make sure to specify --shapefile-name

Usage:

  rails runner import_places_from_shapefile.rb PATH_OR_URL [OPTIONS]

where [options] are:
EOS
  opt :debug, "Print debug statements", :type => :boolean, :short => "-d"
  opt :shapefile_name, "Name of the .shp file inside a zip archive", :type => :string, :short => "-f"
  opt :ancestor, "Existing ancestor of the new places, id or slug", :type => :string, :short => "-a"
  opt :name_column, "Column in the shapefile that holds the names of the new places", :type => :string, :short => "-n", :default => "NAME"
  opt :place_type, "iNat place type for the new places", :type => :string, :short => "-t", :default => 'Open Space'
  opt :source_id, "iNat source ID", :type => :string, :short => "-s"
  opt :source_title, "iNat source title. New source will be made if none found.", :type => :string
end

def system_call(cmd)
  puts "Running #{cmd}"
  system cmd
  puts
end

@path =  ARGV[0] #{}"ftp://ftp.state.ct.us/pub/dep/gis/shapefile_format_zip/DEP_Property_shp.zip"
Trollop::die "You a path to a shapefile" if @path.blank?
@shapefile_name = @opts.shapefile_name || "#{File.basename(@path, ".*")}.shp"
@ancestor_place = Place.find(@opts.ancestor)
@place_type = Place::PLACE_TYPE_CODES[@opts.place_type]
@source = Source.find_by_id(@opts.source_id) if @opts.source_id
if @opts.source_title
  @source ||= Source.find_by_title(@opts.source_title) || Source.create(:title => @opts.source_title)
end

new_shapefile_name = @shapefile_name.gsub(/\.shp/, '_longlat.shp')
filename = File.basename(@path, ".*")
tmp_path = File.join(Dir::tmpdir, "#{File.basename(__FILE__, ".*")}-#{Time.now.to_i}")
archive_path = "#{tmp_path}/#{filename}"
work_path = tmp_path
FileUtils.mkdir_p tmp_path, :mode => 0755

if @path =~ /\.zip$/
  system_call "curl -o #{tmp_path}/#{filename}.zip #{@path}"
  system_call "unzip -d #{tmp_path} #{tmp_path}/#{filename}"
else
  system_call "cp #{File.dirname(@path)}/#{filename}.* #{tmp_path}/"
end

# Reproject shapefile
system_call <<-BASH
  ogr2ogr -t_srs "+proj=longlat +ellps=GRS80 +datum=WGS84 +no_defs" \
      #{work_path}/#{new_shapefile_name} \
      #{work_path}/#{@shapefile_name}
BASH

Place.import_from_shapefile("#{tmp_path}/#{new_shapefile_name}", 
    :name_column => @opts.name_column, 
    :place_type => @place_type, 
    :skip_woeid => true,
    :test => @opts.debug,
    :ancestor_place => @ancestor_place,
    :source => @source)
