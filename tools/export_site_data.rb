require "rubygems"
require "optimist"
require "parallel"

OPTS = Optimist::options do
    banner <<-EOS

Exports select data for a particular site within this installation to CSV files
in a ZIP archive, including observations, users, and anything else network
partners are contractually entitled to. This data is *not* intended to recreate
a full instance of this application. That's what export_site_archive.rb is for.

Relevant observations are assumed to be
  * all records explicitly associated with the site
  * all records in the site's place

Private coordinates will be included for
  * all records explicitly associated with the site
  * all records in the site's place obscured by taxon geoprivacy  

Usage:

  rails runner tools/export_site_data.rb SITE_NAME

where [options] are:
EOS
  opt :debug, "Print debug statements", :type => :boolean, :short => "-d"
  opt :verbose, "Print extra log statements", :type => :boolean, :short => "-v"
  opt :file, "Where to write the zip archive. Default will be tmp path.", :type => :string, :short => "-f"
  opt :dir, "Directory to move files to; overridden by --file", type: :string
  opt :site_name, "Site name", type: :string, short: "-s"
  opt :site_id, "Site ID", type: :string, short: "-i"
  opt :taxon_id, "Taxon ID (just for testing on smaller exports)", type: :string, short: "-t"
end

start_time = Time.now
site_name = OPTS.site_name || ARGV[0]
site = Site.find_by_name( site_name )
site ||= Site.find_by_id( OPTS.site_id )

sites = if site
  [site]
else
  Site.where( "id != ?", Site.default ).where( "NOT draft" )
end

max_obs_id = Observation.calculate(:maximum, :id)
paths = sites.to_a.compact.collect do |site|
  puts
  puts "Exporting data for #{site}..."
  path = SiteDataExporter.new( site, OPTS.merge( max_obs_id: max_obs_id ) ).export
  if OPTS.dir
    new_path = File.join( File.expand_path( OPTS.dir ), File.basename( path ) )
    FileUtils.move( path, new_path )
    path = new_path
  end
  path
end

if sites.size == 1 && OPTS[:file]
  system_call("mv #{archive_path} #{OPTS[:file]}")
  paths = [OPTS[:file]]
end

puts
puts "Exported site data in #{Time.now - start_time} s to the following locations:"
puts
paths.each do |path|
  puts path
end
puts
