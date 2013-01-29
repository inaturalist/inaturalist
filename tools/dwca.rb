require 'rubygems'
require 'trollop'

opts = Trollop::options do
    banner <<-EOS
Exports a Darwin Core Archive from observations.  Archives will be gzip'd tarballs

Usage:

  rails runner dwca.rb

will output licensed observations to public/observations/dwca.zip.

  rails runner tools/dwca.rb -f public/observations/calflora.dwca.zip -t 123635 -p 14

will output licensed observations of taxon 123635 from place 14 to calflora.dwca.zip
  
  rails runner tools/dwca.rb \
    -f public/taxa/eol_media.dwca.zip \
    --core taxon \
    --extensions EolMedia \
    --photo-licenses CC-BY CC-BY-NC CC-BY-SA CC-BY-NC-SA

will output taxon records with the EolMedia extension from a limited set of photo 
licenses.

Options:
EOS
  opt :path, "Path to archive", :type => :string, :short => "-f", :default => "public/observations/dwca.zip"
  opt :place, "Only export observations from this place", :type => :string, :short => "-p"
  opt :taxon, "Only export observations of this taxon", :type => :string, :short => "-t"
  opt :core, "Core type. Options: occurrence, taxon. Default: occurrence.", :type => :string, :short => "-c", :default => "occurrence"
  opt :extensions, "Extensions to include. Options: EolMedia", :type => :strings, :short => "-x"
  opt :metadata, "Path to metadata template. Default: observations/gbif.eml.erb. \"skip\" will skip EML file generation.", :type => :string, :short => "-m", :default => "observations/gbif.eml.erb"
  opt :descriptor, "Path to descriptor template. Default: observations/gbif.descriptor.builder", :type => :string, :short => "-r", :default => "observations/gbif.descriptor.builder"
  opt :quality, "Quality grade of observation output.  This will also filter EolMedia exports. Options: research, casual, any.  Default: research.", :type => :string, :short => "-q", :default => "research"
  opt :photo_licenses, "Photo licenses", :type => :strings, :default => ["CC-BY", "CC-BY-NC", "CC-BY-SA", "CC-BY-ND", "CC-BY-NC-SA", "CC-BY-NC-ND"]
  opt :debug, "Print debug statements", :type => :boolean, :short => "-d"
end

@opts = opts

@place = Place.find_by_id(opts[:place].to_i) || Place.find_by_name(opts[:place])
puts "Found place: #{@place}" if opts[:debug]
@taxon = Taxon.find_by_id(opts[:taxon].to_i) || Taxon.find_by_name(opts[:taxon])
puts "Found taxon: #{@taxon}" if opts[:debug]
puts "Photo licenses: #{@opts[:photo_licenses].inspect}" if opts[:debug]

# Create a Darwin Core Archive from iNat observations
class Metadata < FakeView
  def initialize(options = {})
    super()
    @contact = CONFIG.get(:contact) || {}
    @creator = CONFIG.get(:creator) || @contact || {}
    @metadata_provider = CONFIG.get(:metadata_provider) || @contact || {}
    scope = Observation.scoped({})
    if options[:quality] == "research"
      scope = scope.has_quality_grade(Observation::RESEARCH_GRADE)
    elsif options[:quality] == "casual"
      scope = scope.has_quality_grade(Observation::CASUAL_GRADE)
    end
    scope = scope.license('any')
    scope = scope.has_photos if options[:extensions] && options[:extensions].include?("EolMedia")
    @extent     = scope.calculate(:extent, :geom)
    @start_date = scope.minimum(:observed_on)
    @end_date   = scope.maximum(:observed_on)
  end
end

class Descriptor < FakeView
  def initialize(options = {})
    super()
    @core = options[:core]
    @extensions = options[:extensions]
  end
end

def make_metadata
  m = Metadata.new(@opts)
  tmp_path = File.join(Dir::tmpdir, "metadata.eml.xml")
  open(tmp_path, 'w') do |f|
    f << m.render(:file => @opts[:metadata])
  end
  tmp_path
end

def make_descriptor
  extensions = if @opts[:extensions] && @opts[:extensions].detect{|e| e == "EolMedia"}
    [{
      :row_type => "http://eol.org/schema/media/Document",
      :file_location => "media.csv",
      :terms => EolMedia::TERMS
    }]
  end
  d = Descriptor.new(:core => @opts[:core], :extensions => extensions)
  tmp_path = File.join(Dir::tmpdir, "meta.xml")
  open(tmp_path, 'w') do |f|
    f << d.render(:file => @opts[:descriptor])
  end
  tmp_path
end

def make_data
  paths = [send("make_#{@opts[:core]}_data")]
  if @opts.extensions
    @opts.extensions.each do |ext|
      ext = ext.underscore.downcase
      paths << send("make_#{ext}_data")
    end
  end
  paths
end

def make_occurrence_data
  headers = DarwinCore::Occurrence::TERM_NAMES
  fname = "observations.csv"
  tmp_path = File.join(Dir::tmpdir, fname)
  fake_view = FakeView.new
  
  find_options = {
    :include => [:taxon, {:user => :stored_preferences}, :photos, :quality_metrics, :identifications],
    :conditions => ["observations.license IS NOT NULL"]
  }
  
  if @opts[:quality] == "research"
    find_options[:conditions][0] += " AND quality_grade = ?"
    find_options[:conditions] << Observation::RESEARCH_GRADE
  elsif @opts[:quality] == "casual"
    find_options[:conditions][0] += " AND quality_grade = ?"
    find_options[:conditions] << Observation::Observation::CASUAL_GRADE
  end
  
  if @taxon
    find_options[:conditions][0] += " AND (#{@taxon.descendant_conditions[0]})"
    find_options[:conditions] += @taxon.descendant_conditions[1..-1]
  end
  
  if @place
    find_options[:joins] = "JOIN place_geometries ON place_geometries.place_id = #{@place.id}"
    find_options[:conditions][0] +=
      " AND (" +
        "(observations.private_latitude IS NULL AND ST_Intersects(place_geometries.geom, observations.geom)) OR " +
        "(observations.private_latitude IS NOT NULL AND ST_Intersects(place_geometries.geom, ST_Point(observations.private_longitude, observations.private_latitude)))" +
      ")"
  end
  
  CSV.open(tmp_path, 'w') do |csv|
    csv << headers
    Observation.do_in_batches(find_options) do |o|
      next unless o.user.prefers_gbif_sharing?
      o = DarwinCore::Occurrence.adapt(o, :view => fake_view)
      csv << DarwinCore::Occurrence::TERMS.map{|field, uri, default, method| o.send(method || field)}
    end
  end
  
  tmp_path
end

def make_taxon_data
  headers = DarwinCore::Taxon::TERM_NAMES
  fname = "taxa.csv"
  tmp_path = File.join(Dir::tmpdir, fname)
  licenses = @opts[:photo_licenses].map do |license_code|
    Photo.license_number_for_code(license_code)
  end
  
  find_options = {
    :select => "DISTINCT ON (taxa.id) taxa.*",
    :joins => {:observations => {:observation_photos => :photo}},
    :conditions => [
      "rank_level <= ? AND observation_photos.id IS NOT NULL AND photos.license IN (?)", 
      Taxon::SPECIES_LEVEL, licenses]
  }
  
  if @opts[:quality] == "research"
    find_options[:conditions][0] += " AND observations.quality_grade = ?"
    find_options[:conditions] << Observation::RESEARCH_GRADE
  elsif @opts[:quality] == "casual"
    find_options[:conditions][0] += " AND observations.quality_grade = ?"
    find_options[:conditions] << Observation::Observation::CASUAL_GRADE
  end
  
  if @taxon
    find_options[:conditions][0] += " AND (#{@taxon.descendant_conditions[0]})"
    find_options[:conditions] += @taxon.descendant_conditions[1..-1]
  end
  
  CSV.open(tmp_path, 'w') do |csv|
    csv << headers
    Taxon.do_in_batches(find_options) do |t|
      DarwinCore::Taxon.adapt(t)
      csv << DarwinCore::Taxon::TERMS.map{|field, uri, default, method| t.send(method || field)}
    end
  end
  
  tmp_path
end

def make_eol_media_data
  headers = EolMedia::TERM_NAMES
  fname = "media.csv"
  tmp_path = File.join(Dir::tmpdir, fname)
  licenses = @opts[:photo_licenses].map do |license_code|
    Photo.license_number_for_code(license_code)
  end
  
  find_options = {
    :include => [:user, {:observation_photos => {:observation => :taxon}}],
    :conditions => [
      "photos.license IN (?) AND taxa.rank_level <= ? AND taxa.id IS NOT NULL", 
      licenses, Taxon::SPECIES_LEVEL]
  }
  
  if @opts[:quality] == "research"
    find_options[:conditions][0] += " AND observations.quality_grade = ?"
    find_options[:conditions] << Observation::RESEARCH_GRADE
  elsif @opts[:quality] == "casual"
    find_options[:conditions][0] += " AND observations.quality_grade = ?"
    find_options[:conditions] << Observation::Observation::CASUAL_GRADE
  end
  
  if @taxon
    find_options[:conditions][0] += " AND (#{@taxon.descendant_conditions[0]})"
    find_options[:conditions] += @taxon.descendant_conditions[1..-1]
  end
  
  if @place
    find_options[:joins] = "JOIN place_geometries ON place_geometries.place_id = #{@place.id}"
    find_options[:conditions][0] +=
      " AND (" +
        "(observations.private_latitude IS NULL AND ST_Intersects(place_geometries.geom, observations.geom)) OR " +
        "(observations.private_latitude IS NOT NULL AND ST_Intersects(place_geometries.geom, ST_Point(observations.private_longitude, observations.private_latitude)))" +
      ")"
  end
  
  CSV.open(tmp_path, 'w') do |csv|
    csv << headers
    Photo.do_in_batches(find_options) do |t|
      EolMedia.adapt(t)
      csv << EolMedia::TERMS.map{|field, uri, default, method| t.send(method || field)}
    end
  end
  
  tmp_path
end

def make_archive(*args)
  fname = "dwca.zip"
  tmp_path = File.join(Dir::tmpdir, fname)
  fnames = args.map{|f| File.basename(f)}
  system "cd #{Dir::tmpdir} && zip -D #{tmp_path} #{fnames.join(' ')}"
  tmp_path
end

unless @opts[:metadata].to_s.downcase == "skip"
  metadata_path = make_metadata
  puts "Metadata: #{metadata_path}" if opts[:debug]
end
descriptor_path = make_descriptor
puts "Descriptor: #{descriptor_path}" if opts[:debug]
data_paths = make_data
puts "Data: #{data_paths.inspect}" if opts[:debug]
paths = [metadata_path, descriptor_path, data_paths].flatten.compact
archive_path = make_archive(*paths)
puts "Archive: #{archive_path}" if opts[:debug]
FileUtils.mv(archive_path, opts[:path])
puts "Archive generated: #{opts[:path]}"
