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


  rails runner tools/dwca.rb \
    -f public/taxa/CC-BY.dwca.zip \
    --license CC-BY \
    --licenses CC-BY

will output observation records that have the CC BY license, and will license
the entire archive under a CC BY license.

Options:
EOS
  opt :path, "Path to archive", type: :string, short: "-f", default: "public/observations/dwca.zip"
  opt :place, "Only export observations from this place", type: :string, short: "-p"
  opt :taxon, "Only export observations of this taxon", type: :string, short: "-t"
  opt :project, "Only export observations from this project", type: :string, short: "-o"
  opt :core,
    "Core type. Options: occurrence, taxon. Default: occurrence.",
    type: :string, short: "-c", default: "occurrence"
  opt :extensions, "Extensions to include. Options: EolMedia, SimpleMultimedia, ObservationFields, ProjectObservations, User",
    type: :strings, short: "-x"
  opt :metadata, "
    Path to metadata template. Default: observations/gbif.eml.erb. \"skip\" will skip EML file generation.
  ".strip.gsub( /\s+/m, " " ), type: :string, short: "-m", default: "observations/gbif.eml.erb"
  opt :descriptor, "Path to descriptor template. Default: observations/gbif.descriptor.builder",
    type: :string, short: "-r", default: "observations/gbif.descriptor.builder"
  opt :quality, "
    Quality grade of observation output.  This will also filter EolMedia
    exports. Options: research, casual, any.
  ".strip.gsub( /\s+/m, " " ), type: :string, short: "-q", default: "research"
  opt :license, "Archive license that applies to the entire archive. Optional.", type: :string
  opt :licenses, "  
    Observation licenses. Set to 'ignore' to include unlicensed observations,
    'any' to include all licensed observations.
  ".strip.gsub( /\s+/m, " " ), type: :strings, default: ["any"]
  opt :photo_licenses, "
    Photo licenses. Set to 'ignore' to include unlicensed observations, 'any'
    to include all licensed observations.
  ".strip.gsub( /\s+/m, " " ), type: :strings
  opt :private_coordinates, "Include private coordinates", type: :boolean, default: false
  opt :site_id, "Only include obs from a particular site", type: :integer
  opt :debug, "Print debug statements", type: :boolean, short: "-d"
  opt :benchmark, "Print benchmarks", type: :boolean, short: "-b"
  opt :additional_with_taxa_path, "Create a second archive with a taxa.csv file", type: :string
  opt :post_taxon_archive_to_url, "Post the second archive with taxa.csv to this URL", type: :string
  opt :post_taxon_archive_as_url, "URL the second archive will be posted as", type: :string
end

if opts.debug
  opts[:logger] = Logger.new(STDOUT, level: Logger::DEBUG)
end
DarwinCore::Archive.generate(opts)
