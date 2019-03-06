require "rubygems"
require "optimist"

opts = Optimist::options do
    banner <<-EOS
Executes a SQL query over a range of ids.  Useful for memory hogging queries.

Usage:

  ruby tools/psql_batch.rb [options] some sql
  
where [options] are:
EOS
  # opt :sql, "SQL to execute", 
  #   :type => :string, :short => "-s"
  opt :database, "Database to use", 
    :type => :string, :short => "-d", :default => "inaturalist_development"
  opt :batch_size, "Number of rows to run this on in a batch", 
    :type => :int, :short => "-b", :default => 1000
  opt :offset, "Starting offset", 
    :type => :int, :short => "-o", :default => 0
  opt :max, "Max number of rows", 
    :type => :int, :short => "-m", :default => 10000
  opt :batch_column, "Column to use for batch iteration",
    :type => :string, :short => "-c", :default => "id"
end

sql = ARGV.last

Optimist::die "sql must be specified" if sql.to_s == ''

((opts[:max] - opts[:offset]) / opts[:batch_size]).times do |i|
  start = opts[:offset] + i * opts[:batch_size]
  stop  = opts[:offset] + i * opts[:batch_size] + opts[:batch_size] - 1
  run = if sql =~ /WHERE/i
    sql.sub(/WHERE/i, "WHERE #{opts[:batch_column]} BETWEEN #{start} AND #{stop} AND")
  else
    sql + " WHERE #{opts[:batch_column]} BETWEEN #{start} AND #{stop}"
  end
  cmd = "psql #{opts[:database]} -c \"#{run}\""
  puts "Running #{cmd}..."
  system cmd
end
