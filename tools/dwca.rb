require "rubygems"
require "optimist"

opts = Optimist.options do
  banner <<-HELP
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
  HELP

  opt :path, "Path to archive", type: :string, short: "-f", default: "public/observations/dwca.zip"
  opt :aws_s3_path, "Path to upload archive to configured AWS account/bucket", type: :string
  opt :place, "Only export observations from this place", type: :string, short: "-p"
  opt :taxon, "Only export observations of this taxon", type: :string, short: "-t"
  opt :project, "Only export observations from this project", type: :string, short: "-o"
  opt :core,
    "Core type. Options: occurrence, taxon",
    type: :string, short: "-c", default: "occurrence"
  opt :extensions, "Extensions to include. Options: EolMedia, SimpleMultimedia, ObservationFields, ProjectObservations, User, VernacularNames (taxon core only)",
    type: :strings, short: "-x"
  opt :metadata, "
    Path to metadata template. Default: {core}/dwc.eml.erb. \"skip\" will skip EML file generation.
  ".strip.gsub( /\s+/m, " " ), type: :string, short: "-m"
  opt :descriptor, "Path to descriptor template",
    type: :string, short: "-r",
    default: File.join( "observations", "dwc_descriptor" )
  opt :quality, "
    Quality grade of observation output.  This will also filter EolMedia
    exports. Options: research, casual, verifiable, any.
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
  opt :photos, "Whether or not to include obs with photos", type: :string
  opt :private_coordinates, "Include private coordinates", type: :boolean, default: false
  opt :taxon_private_coordinates, "Include private coordinates if obscured by taxon geoprivacy but not user geoprivacy", type: :boolean, default: false
  opt :site_id, "Only include obs from a particular site", type: :integer
  opt :debug, "Print debug statements", type: :boolean, short: "-d"
  opt :benchmark, "Print benchmarks", type: :boolean, short: "-b"
  opt :with_taxa, "Include a taxa.csv file if the core is observations", type: :boolean
  opt :post_taxon_archive_to_url, "Post the second archive with taxa.csv to this URL", type: :string
  opt :post_taxon_archive_as_url, "URL the second archive will be posted as", type: :string
  opt :community_taxon, "Use the community taxon for the taxon associated with the occurrence, not the default taxon",
    type: :boolean
  opt :d1, "Mininum date of observation", type: :string
  opt :d2, "Maximum date of observation", type: :string
  opt :created_d1, "Mininum date of observation creation", type: :string
  opt :created_d2, "Maximum date of observation creation", type: :string
  opt :photographed_taxa, "When core is taxon, only include taxa with observation photos", type: :boolean, default: false
  opt :ala, "Add ALA requested fields", type: :boolean, default: false
  opt :ofv_datatype, "Filter obs by datatype of observation field values", type: :string
  opt :freq, "Frequency with which this archive gets updated. See MaintUpFreqType in http://rs.gbif.org/schema/eml-2.1.1/eml-dataset.xsd for values.", type: :string
  opt :swlng, "Bounding box left longitude", type: :double
  opt :swlat, "Bounding box bottom latitude", type: :double
  opt :nelng, "Bounding box right longitude", type: :double
  opt :nelat, "Bounding box top latitude", type: :double
  opt :include_uuid, "Add observation UUIDs as otherCatalogNumbers", type: :boolean, default: false
  opt :with_annotations, "Only include observations with annotations that have occurrence fields", type: :boolean, default: false
  opt :with_controlled_terms, "Only include observations with annotations of this term name", type: :strings
  opt :with_controlled_values, "Only include observations with annotations with this value (must be combined with `with_controlled_terms`)", type: :strings
  opt :processes, "Number of processes to use with the parallel gem", type: :integer
end

if opts.debug
  opts[:logger] = Logger.new(STDOUT, level: Logger::DEBUG)
else
  opts[:logger] = Logger.new(STDOUT, level: Logger::INFO)
end
DarwinCore::Archive.generate(opts)
