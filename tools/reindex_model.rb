#
# Reindex a given model with parallel processes, e.g. rails r
# tools/reindex_model.rb Taxon 3 to reindex the taxon index with 3 parallel
# processes
#
require "optimist"
require "parallel"

opts = Optimist::options do
    banner <<-EOS
Reindex all records of a model with parallel processes.

Usage:
  rails runner tools/reindex_model.rb Observation --num-processes 3 --max-id 100

Options:
EOS
  opt :num_processes, "Number of reindexing processes to run in parallel",
    type: :integer, short: "-n", default: 4
  opt :max_id, "Maximum ID to consider.", type: :integer
  opt :max_date, "Maximum date last indexed to consider.", type: :string
end
@opts = opts

klass = Object.const_get( ARGV[0] )
num_processes = @opts[:num_processes]
max_id = ( @opts[:max_id] || klass.calculate(:maximum, :id) ).to_i
offset = max_id / num_processes
puts "Reindexing #{klass} index with #{num_processes} processes"
Parallel.map( 0...num_processes, in_processes: num_processes ) do |i|
  start = offset * i
  limit = i == ( num_processes - 1 ) ? max_id : start + offset
  puts "Starting process #{i}, #{start} - #{limit}"
  scope = klass.where( "id BETWEEN ? AND ?", start, limit )
  if @opts[:max_date]
    scope = scope.where( "last_indexed_at <= ?", @opts[:max_date] )
  end
  klass.elastic_index!( scope: scope )
  puts "Finished process #{i}"
end
