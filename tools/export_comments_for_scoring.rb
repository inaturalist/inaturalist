# frozen_string_literal: true

require "rubygems"
require "optimist"

OPTS = Optimist.options do
  banner <<~HELP
    Exports non-spam comments on Research Grade observations whose
    identification history never had a genuinely conflicting
    identification -- a different branch of the tree (e.g. "plant" vs.
    "insect"), as opposed to a same-lineage refinement (e.g. "moth" -> a
    specific moth species), whether current or withdrawn. That history
    check is what makes it safe to associate a comment with the
    observation's current taxon.

    Cutoff-parameterized by comments.id:
      * --cutoff-id 0    exports everything (the initial full export)
      * --cutoff-id N    exports only comments with id > N (an incremental
                         run; use the max id printed by the previous run)

    Columns: comment_id, body, comment_user_id, comment_user_login,
    observation_id, taxon_id, taxon_name, taxon_common_name, taxon_rank,
    iconic_taxon_name

    Usage:

      # Initial full export
      rails runner tools/export_comments_for_scoring.rb --cutoff-id 0

      # Later incremental export from the last max id
      rails runner tools/export_comments_for_scoring.rb -c 87654321 -f ~/comments_for_scoring.csv

    where [options] are:
  HELP
  opt :debug, "Print debug statements", type: :boolean, short: "-d"
  opt :file, "Where to write output. Default will be tmp path.", type: :string, short: "-f"
  opt :cutoff_id, "Only export rows with comments.id greater than this (0 for a full export)", type: :integer, short: "-c", required: true
  opt :batch_id_span, "Number of comment ids to scan per batch window", type: :integer, default: 100_000
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
out_path = OPTS.file || File.join( work_path, "comments_for_scoring_from_#{cutoff_id}.csv" )

HEADERS = %w[
  comment_id
  body
  comment_user_id
  comment_user_login
  observation_id
  taxon_id
  taxon_name
  taxon_common_name
  taxon_rank
  iconic_taxon_name
].freeze

PLUCK_COLUMNS = %w[
  comments.id
  comments.body
  comments.user_id
  users.login
  o.id
  o.taxon_id
  taxa.name
  taxa.rank
  taxa.iconic_taxon_id
].freeze

scope = Comment.
  not_flagged_as_spam.
  joins( "INNER JOIN observations o ON o.id = comments.parent_id" ).
  joins( "LEFT JOIN taxa ON taxa.id = o.taxon_id" ).
  where( "comments.parent_type = 'Observation'" ).
  where( "o.quality_grade = 'research'" ).
  # Exclude observations whose identification history ever contained a
  # 'maverick' -- an identification on a genuinely different branch of the
  # tree (not a same-lineage refinement). Indexed per-row check on
  # identifications (observation_id, category).
  where( <<~SQL )
    NOT EXISTS (
      SELECT 1 FROM identifications i
      WHERE i.observation_id = o.id AND i.category = 'maverick'
    )
  SQL

count = 0
chunk_size = OPTS.batch_id_span
max_id = [Comment.maximum( :id ).to_i, cutoff_id].max
common_name_by_taxon_id = {}

puts "Exporting comments (cutoff_id=#{cutoff_id}, max comments.id=#{max_id}, " \
     "id span=#{chunk_size}) -> #{out_path}"

CSV.open( out_path, "wb", force_quotes: true, encoding: "UTF-8" ) do |csv|
  csv << HEADERS

  chunk_start_id = cutoff_id + 1
  while chunk_start_id <= max_id
    chunk_id_below = chunk_start_id + chunk_size
    rows = scope.
      where( "comments.id >= ?", chunk_start_id ).
      where( "comments.id < ?", chunk_id_below ).
      pluck( *PLUCK_COLUMNS )
    load_common_names( rows.map {| r | r[5] }, common_name_by_taxon_id )

    rows.each do |row|
      comment_id, body, user_id, login, observation_id, taxon_id,
        taxon_name, taxon_rank, iconic_taxon_id = row

      csv << [
        comment_id,
        sanitize_text( body ),
        user_id,
        login,
        observation_id,
        taxon_id,
        taxon_name,
        common_name_by_taxon_id[taxon_id],
        taxon_rank,
        Taxon::ICONIC_TAXA_BY_ID[iconic_taxon_id]&.name
      ]

      count += 1
    end

    if OPTS.debug
      puts "  comments.id #{chunk_start_id}..#{chunk_id_below - 1}: " \
           "#{count} rows written (#{( Time.now - start ).round}s elapsed)"
    end
    chunk_start_id += chunk_size
  end
end

puts "Done: #{count} rows -> #{out_path} (#{( Time.now - start ).round}s)"
puts "Max comments.id seen: #{max_id} " \
     "(use as --cutoff-id for the next incremental run)"
