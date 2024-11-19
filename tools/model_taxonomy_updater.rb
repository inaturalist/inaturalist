# frozen_string_literal: true

require "rubygems"
require "optimist"
require "model_taxonomy_updater"

OPTS = Optimist.options do
  banner <<-BANNER

  Export synonym mappings and an updated taxonomy, given a path to a model taxonomy.
  Synonyms are based on taxon changed committed since a given start date.

  Usage:

    rails runner tools/model_taxonomy_updater.rb -t TAXONOMY_PATH -s CHANGES_SINCE -o OUTPUT_DIR

  where [options] are:
  BANNER
  opt :model_taxonomy_path, "Path to the model taxonomy CSV file.", type: :string, short: "-t"
  opt :changes_committed_since, "Date after which changes must be committed.", type: :string, short: "-s"
  opt :output_dir, "Directory to copy the resulting output.", type: :string, short: "-o"
end

unless OPTS.model_taxonomy_path
  puts "You must specify a model taxonomy path"
  exit( 0 )
end

START_DATE = Date.parse( OPTS.changes_committed_since )
unless START_DATE
  puts "You must specify a valid start date"
  exit( 0 )
end

if OPTS.output_dir && !File.directory?( OPTS.output_dir )
  puts "`output_dir` missing or not a directory"
  exit( 0 )
end

load "model_taxonomy_updater.rb"
ModelTaxonomyUpdater.new(
  OPTS.model_taxonomy_path,
  START_DATE,
  OPTS.output_dir
).process
