# frozen_string_literal: true

require "rubygems"
require "optimist"

OPTS = Optimist.options do
  banner <<~HELP
    Exports every ExemplarIdentification with active: true -- an
    identification remark that currently follows the exemplar/ID-tip
    criteria -- regardless of nomination status.

    Cutoff-parameterized by exemplar_identifications.id:
      * --cutoff-id 0    exports everything (the initial full export)
      * --cutoff-id N    exports only rows with id > N (an incremental
                         run; use the max id printed by the previous run)

    Columns: identification_id, body, identification_user_id,
    identification_user_login, taxon_id, taxon_name, taxon_common_name,
    taxon_rank, iconic_taxon_name

    Usage:

      # Initial full export
      rails runner tools/export_identifications_for_scoring.rb --cutoff-id 0

      # Later incremental export from the last max id
      rails runner tools/export_identifications_for_scoring.rb -c 12345678 -f ~/identifications_for_scoring.csv

    where [options] are:
  HELP
  opt :debug, "Print debug statements", type: :boolean, short: "-d"
  opt :file, "Where to write output. Default will be tmp path.", type: :string, short: "-f"
  opt :cutoff_id, "Only export rows with exemplar_identifications.id greater than this (0 for a full export)", type: :integer, short: "-c", required: true
  opt :batch_id_span, "Number of exemplar_identifications ids to scan per batch window", type: :integer, default: 100_000
end

require "csv"

def sanitize_text( str )
  s = str.to_s
  s = s.gsub( /\r\n?|\n/, " " )
  s = s.gsub( /[\p{Cntrl}&&[^\r\n\t]]/, "" )
  s.gsub( /\s+/, " " ).strip
end

def load_common_names( taxon_ids, cache )
  missing = taxon_ids.compact.uniq - cache.keys
  return if missing.empty?

  missing.each {| id | cache[id] = nil }
  TaxonName.
    where( taxon_id: missing, is_valid: true ).
    where( lexicon: TaxonName::LEXICONS[:ENGLISH] ).
    order( "taxon_id ASC, position ASC NULLS LAST, id ASC" ).
    pluck( :taxon_id, :name ).
    each {| taxon_id, name | cache[taxon_id] ||= name }
end

start = Time.now
cutoff_id = OPTS.cutoff_id
work_path = Dir.mktmpdir
FileUtils.mkdir_p work_path, mode: 0755
out_path = OPTS.file || File.join( work_path, "identifications_for_scoring_from_#{cutoff_id}.csv" )

HEADERS = %w[
  identification_id
  body
  identification_user_id
  identification_user_login
  taxon_id
  taxon_name
  taxon_common_name
  taxon_rank
  iconic_taxon_name
].freeze

PLUCK_COLUMNS = %w[
  exemplar_identifications.id
  identifications.id
  identifications.body
  identifications.user_id
  users.login
  identifications.taxon_id
  taxa.name
  taxa.rank
  taxa.iconic_taxon_id
].freeze

scope = ExemplarIdentification.
  where( active: true ).
  joins( :identification ).
  joins( "LEFT JOIN users ON users.id = identifications.user_id" ).
  joins( "LEFT JOIN taxa ON taxa.id = identifications.taxon_id" )

count = 0
chunk_size = OPTS.batch_id_span
max_id = [ExemplarIdentification.maximum( :id ).to_i, cutoff_id].max
common_name_by_taxon_id = {}

puts "Exporting identifications (cutoff_id=#{cutoff_id}, " \
     "max exemplar_identifications.id=#{max_id}, id span=#{chunk_size}) -> #{out_path}"

CSV.open( out_path, "wb", force_quotes: true, encoding: "UTF-8" ) do |csv|
  csv << HEADERS

  chunk_start_id = cutoff_id + 1
  while chunk_start_id <= max_id
    chunk_id_below = chunk_start_id + chunk_size
    rows = scope.
      where( "exemplar_identifications.id >= ?", chunk_start_id ).
      where( "exemplar_identifications.id < ?", chunk_id_below ).
      pluck( *PLUCK_COLUMNS )
    load_common_names( rows.map {| r | r[5] }, common_name_by_taxon_id )

    rows.each do |row|
      exemplar_id, identification_id, body, user_id, login, taxon_id,
        taxon_name, taxon_rank, iconic_taxon_id = row

      csv << [
        identification_id,
        sanitize_text( body ),
        user_id,
        login,
        taxon_id,
        taxon_name,
        common_name_by_taxon_id[taxon_id],
        taxon_rank,
        Taxon::ICONIC_TAXA_BY_ID[iconic_taxon_id]&.name
      ]

      count += 1
    end

    if OPTS.debug
      puts "  exemplar_identifications.id #{chunk_start_id}..#{chunk_id_below - 1}: " \
           "#{count} rows written (#{( Time.now - start ).round}s elapsed)"
    end
    chunk_start_id += chunk_size
  end
end

puts "Done: #{count} rows -> #{out_path} (#{( Time.now - start ).round}s)"
puts "Max exemplar_identifications.id seen: #{max_id} " \
     "(use as --cutoff-id for the next incremental run)"
