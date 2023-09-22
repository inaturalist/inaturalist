require "rubygems"
require "optimist"

# The official list of locales current supported by Seek can be found at:
# https://github.com/inaturalist/SeekReactNative/blob/main/i18n.js

SEEK_LOCALES = [
  "af", "ar", "bg", "ca", "cs", "da", "de", "el", "en", "es", "eu", 
  "fi", "fr", "he", "hr", "hu", "id", "it", "ja", "nl", "nb", "pl",
  "ptBR", "ro", "ru", "si", "sv", "tr", "uk", "zh"
]

OPTS = Optimist::options do
    banner <<-EOS

Generate a series of files containing the common names the Seek app needs to
localize common names for the vision model it uses and the languages the app
supports.

Usage:

  rails runner tools/seek_common_names.rb

where [options] are:
EOS
  # taxonomy_csv_path should be the taxonomy.csv file included in the deployed "slim" vision model
  opt :taxonomy_csv_path,
    "Path to taxonomy CSV containing the taxa whose names will be exported. It should have a `taxon_id` column containing taxon IDs for all relevant taxa.",
    type: :string, short: "-t"
  opt :names_per_file, "Maximum number of common names to put in each file.",
    type: :integer, short: "-n", default: 10000
end

unless OPTS.taxonomy_csv_path
  puts "You must specify a taxonomy_csv_path"
  exit( 0 )
end

unless File.exist?( OPTS.taxonomy_csv_path )
  puts "There is no file at #{ OPTS.taxonomy_csv_path }"
  exit( 0 )
end

relevant_taxa = { }
begin
  CSV.foreach( OPTS.taxonomy_csv_path, headers: true ) do |row|
    # ignore non-leaves
    relevant_taxa[row["taxon_id"].to_i] = true
  end
rescue
  puts "There was an error reading #{ OPTS.taxonomy_csv_path }"
  exit( 0 )
end

if relevant_taxa.blank?
  puts "No taxa were found"
  exit( 0 )
end

places_by_locale = SEEK_LOCALES.inject( {} ) do |memo,locale|
  locale, lang, region = locale.match( /([a-z]{2})([A-Z]{2})?/ ).to_a
  memo[locale] = if region
    Place.where( admin_level: Place::COUNTRY_LEVEL, code: region ).first
  end
  memo
end

common_names = []
taxon_ids = relevant_taxa.keys
taxon_ids.in_groups_of( 1000, false ) do |group|
  taxa = Taxon.where( id: group ).includes( :taxon_names )
  taxa.each do |taxon|
    SEEK_LOCALES.each do |locale|
      common_name = taxon.common_name( locale: locale, place: places_by_locale[locale] )
      if common_name
        common_names << { i: taxon.id, l: locale, n: common_name.name }
      end
    end
  end
end

index = 0
FileUtils.mkdir_p( "./commonNames" )
common_names.in_groups_of( OPTS.names_per_file, false ) do |name_group|
  common_names_file = File.open( "./commonNames/commonNamesDict-#{ index }.js", "w" )
  common_names_file.sync = true
  common_names_file.write( "const commonNames = #{name_group.to_json};\n\n" )
  common_names_file.write( "export default commonNames;\n" )
  index += 1
end
