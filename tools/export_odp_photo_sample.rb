require "rubygems"
require "optimist"
require "csv"

OPTS = Optimist::options do
    banner <<-EOS

Export the most recent photos stored in the open data (ODP) S3 bucket to a CSV
with the columns id, file_file_name, prefix

Usage:

  rails runner tools/export_odp_photo_sample.rb
  rails runner tools/export_odp_photo_sample.rb --limit 1000 --file odp-photo-sample.csv
  rails runner tools/export_odp_photo_sample.rb --bucket inaturalist-open-data

where [options] are:
EOS
  opt :limit, "Number of photos to export", type: :int, short: "-l", default: 1000
  opt :file, "Where to write output", type: :string, short: "-f", default: "odp-photo-sample.csv"
  opt :bucket, "Open data bucket name to match in file prefixes. Defaults to CONFIG.s3_public_bucket",
    type: :string, short: "-b"
  opt :chunk_size, "Number of photo IDs to scan per query", type: :int, short: "-c", default: 100_000
  opt :max_ids, "Stop after scanning this many photo IDs back from the newest", type: :int,
    short: "-m", default: 10_000_000
end

bucket = OPTS.bucket || ( LocalPhoto.odp_s3_bucket_enabled? && LocalPhoto.s3_bucket( true ) )
abort "No open data bucket configured (CONFIG.s3_public_bucket); pass --bucket" if bucket.blank?

# file_prefixes is tiny, so resolve the ODP prefixes here instead of joining
prefixes = FilePrefix.where( "prefix LIKE ?", "%#{bucket}%" ).pluck( :id, :prefix ).to_h
abort "No file prefixes match #{bucket}" if prefixes.empty?
puts "Matching prefixes: #{prefixes.inspect}"

# photos.file_prefix_id is not indexed, so walk the primary key backwards in
# bounded chunks. An unbounded ORDER BY id DESC LIMIT will scan the whole table
# if few photos match
max_id = LocalPhoto.maximum( :id )
floor_id = max_id - OPTS.max_ids
rows = []
while rows.size < OPTS.limit && max_id > floor_id
  min_id = [max_id - OPTS.chunk_size, floor_id].max
  rows += LocalPhoto.
    where( file_prefix_id: prefixes.keys ).
    where( "photos.id > ? AND photos.id <= ?", min_id, max_id ).
    order( id: :desc ).
    limit( OPTS.limit - rows.size ).
    pluck( :id, :file_file_name, :file_prefix_id )
  max_id = min_id
end

if rows.size < OPTS.limit
  puts "Only found #{rows.size} photos in the newest #{OPTS.max_ids} photo IDs"
end

CSV.open( OPTS.file, "w" ) do | csv |
  csv << %w(id file_file_name prefix)
  rows.each {| id, file_file_name, file_prefix_id | csv << [id, file_file_name, prefixes[file_prefix_id]] }
end

puts "Wrote #{rows.size} photos to #{OPTS.file}"
