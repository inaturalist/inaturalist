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

DarwinCore::Archive.generate(opts)
