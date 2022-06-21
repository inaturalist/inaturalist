# frozen_string_literal: true

require "rubygems"
require "optimist"
require "parallel"

OPTS = Optimist.options do
  banner <<~HELP
    Exports select data for sites within this installation to CSV files
    in ZIP archives, including observations, users, and anything else network
    partners are contractually entitled to. This data is *not* intended to recreate
    a full instance of this application. That's what export_site_archive.rb is for.

    Relevant observations are assumed to be
      * all records explicitly associated with the site
      * all records in the site's place

    Private coordinates will be included for
      * all records explicitly associated with the site
      * all records in the site's place obscured by taxon geoprivacy

    If no single site is specified, it will create exports for *all* the active
    non-default sites.

    Usage:

      # Export a single archive for SITE_NAME
      rails runner tools/export_site_data.rb SITE_NAME

      # Export a single archive for site 13 to a path
      rails runner tools/export_site_data.rb -i 13 -f ~/test.zip

      # Export archives for all non-default sites to the user's home dir
      rails runner tools/export_site_data.rb --dir ~/

    where [options] are:
  HELP
  opt :debug, "Print debug statements", type: :boolean, short: "-d"
  opt :verbose, "Print extra log statements", type: :boolean, short: "-v"
  opt :file, "Where to write the zip archive. Default will be tmp path.", type: :string, short: "-f"
  opt :dir, "Directory to move files to; overridden by --file", type: :string
  opt :num_processes, "Max number of parallel processes to use for exporting", type: :integer, short: "-p", default: 3
  opt :site_name, "Site name", type: :string, short: "-s"
  opt :site_id, "Site ID", type: :string, short: "-i"
  opt :taxon_id, "Taxon ID (just for testing on smaller exports)", type: :string, short: "-t"
end

def system_call( cmd )
  puts "Running #{cmd}" if OPTS[:debug]
  system cmd
end

start_time = Time.now
site_name = OPTS.site_name || ARGV[0]
site = Site.find_by_name( site_name )
site ||= Site.find_by_id( OPTS.site_id )

sites = if site
  [site]
else
  # Note that we are sorting by id DESC b/c more recent sites tend to have
  # smaller exports, so that should reveal problems a bit sooner
  Site.where( "id != ?", Site.default ).where( "NOT draft" ).order( "id DESC" )
end

max_obs_id = Observation.calculate( :maximum, :id )
export_params = {
  max_obs_id: max_obs_id,
  debug: OPTS.debug,
  verbose: OPTS.verbose,
  taxon_id: OPTS.taxon_id,
  num_processes: OPTS.num_processes
}
paths = sites.to_a.compact.collect do | site_to_export |
  puts
  puts "Exporting data for #{site_to_export}..."
  path = SiteDataExporter.new( site_to_export, export_params ).export
  if OPTS.dir
    new_path = File.join( File.expand_path( OPTS.dir ), File.basename( path ) )
    FileUtils.move( path, new_path )
    path = new_path
  end
  path
end

if paths.size == 1 && OPTS[:file]
  system_call( "mv #{paths[0]} #{OPTS[:file]}" )
  paths = [OPTS[:file]]
end

puts
puts "Exported site data in #{Time.now - start_time} s to the following locations:"
puts
paths.each do | path |
  puts path
end
puts
