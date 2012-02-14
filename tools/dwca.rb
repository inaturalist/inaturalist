require 'rubygems'
require 'trollop'

opts = Trollop::options do
    banner <<-EOS
Exports a Darwin Core Archive from observations.  Archives will be gzip'd tarballs

Usage:

  script/runner dwca.rb

will output licensed observations to public/observations/dwca.zip

where [options] are:
EOS
  opt :path, "Path to archive", :type => :string, :short => "-f", :default => "public/observations/dwca.zip"
  opt :place, "Only export observations from this place", :type => :string, :short => "-p"
  opt :taxon, "Only export observations of this taxon", :type => :string, :short => "-t"
  opt :debug, "Print debug statements", :type => :boolean, :short => "-d"
end

@place = Place.find_by_id(opts[:place].to_i) || Place.find_by_name(opts[:place])
puts "Found place: #{@place}" if opts[:debug]
@taxon = Taxon.find_by_id(opts[:taxon].to_i) || Taxon.find_by_name(opts[:taxon])
puts "Found taxon: #{@taxon}" if opts[:debug]

# Create a Darwin Core Archive from iNat observations
class Metadata < DarwinCore::FakeView
  def initialize
    super
    @contact = INAT_CONFIG["general"]["contact"] || {}
    @creator = INAT_CONFIG["general"]["creator"] || @contact || {}
    @metadata_provider = INAT_CONFIG["general"]["metadata_provider"] || @contact || {}
    scope = Observation.scoped({})
    scope = scope.has_quality_grade(Observation::RESEARCH_GRADE)
    scope = scope.scoped(
      :include => {:user => :stored_preferences},
      :conditions => "preferences.id IS NULL OR (preferences.name = 'gbif_sharing' AND preferences.value != 'f')")
    @extent     = scope.calculate(:extent, :geom)
    @start_date = scope.minimum(:observed_on)
    @end_date   = scope.maximum(:observed_on)
  end
end

def make_metadata
  m = Metadata.new
  tmp_path = File.join(Dir::tmpdir, "metadata.eml.xml")
  open(tmp_path, 'w') do |f|
    f << m.render(:file => 'observations/gbif.eml.erb')
  end
  tmp_path
end

def make_descriptor
  d = DarwinCore::FakeView.new
  tmp_path = File.join(Dir::tmpdir, "meta.xml")
  open(tmp_path, 'w') do |f|
    f << d.render(:file => 'observations/gbif.descriptor.builder')
  end
  tmp_path
end

def make_data
  headers = DarwinCore::DARWIN_CORE_TERM_NAMES
  fname = "observations.csv"
  tmp_path = File.join(Dir::tmpdir, fname)
  fake_view = DarwinCore::FakeView.new
  
  find_options = {
    :include => [:taxon, {:user => :stored_preferences}, :photos, :quality_metrics, :identifications],
    :conditions => ["observations.license IS NOT NULL AND quality_grade = ?", Observation::RESEARCH_GRADE]
  }
  
  if @taxon
    find_options[:conditions][0] += " AND (#{@taxon.descendant_conditions[0]})"
    find_options[:conditions] += @taxon.descendant_conditions[1..-1]
  end
  
  if @place
    find_options[:joins] = "JOIN place_geometries ON place_geometries.place_id = #{@place.id}"
    # find_options[:from] = "observations, place_geometries"
    find_options[:conditions][0] +=
      " AND (" +
        "(observations.private_latitude IS NULL AND ST_Intersects(place_geometries.geom, observations.geom)) OR " +
        "(observations.private_latitude IS NOT NULL AND ST_Intersects(place_geometries.geom, ST_Point(observations.private_longitude, observations.private_latitude)))" +
      ")"
  end
  
  FasterCSV.open(tmp_path, 'w') do |csv|
    csv << headers
    Observation.do_in_batches(find_options) do |o|
      next unless o.user.prefers_gbif_sharing?
      o = DarwinCore.adapt(o, :view => fake_view)
      csv << headers.map{|h| o.send(h)}
    end
  end
  
  tmp_path
end

def make_archive(*args)
  fname = "dwca.zip"
  tmp_path = File.join(Dir::tmpdir, fname)
  fnames = args.map{|f| File.basename(f)}
  system "cd #{Dir::tmpdir} && zip #{tmp_path} #{fnames.join(' ')}"
  # system "cd #{Dir::tmpdir} && tar cvzf #{tmp_path} #{fnames.join(' ')}"
  tmp_path
end

metadata_path = make_metadata
puts "Metadata: #{metadata_path}" if opts[:debug]
descriptor_path = make_descriptor
puts "Descriptor: #{descriptor_path}" if opts[:debug]
data_path = make_data
puts "Data: #{data_path}" if opts[:debug]
archive_path = make_archive(metadata_path, descriptor_path, data_path)
puts "Archive: #{archive_path}" if opts[:debug]
FileUtils.mv(archive_path, opts[:path])
puts "Archive generated: #{opts[:path]}"
