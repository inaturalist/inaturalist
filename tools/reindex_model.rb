#
# Reindex a given model with parallel processes, e.g. rails r
# tools/reindex_model.rb Taxon 3 to reindex the taxon index with 3 parallel
# processes
#

require "parallel"

klass = Object.const_get( ARGV[0] )
num_processes = ( ARGV[1] || 4 ).to_i
max_id = klass.calculate(:maximum, :id)
offset = max_id / num_processes
puts "Reindexing #{klass} index with #{num_processes} processes"
Parallel.map( 0...num_processes, in_processes: num_processes ) do |i|
  start = offset * i
  limit = i == ( num_processes - 1 ) ? max_id : start + offset
  puts "Starting process #{i}, #{start} - #{limit}"
  klass.elastic_index!( scope: klass.where( "id BETWEEN ? AND ?", start, limit ) )
  puts "Finished process #{i}"
end