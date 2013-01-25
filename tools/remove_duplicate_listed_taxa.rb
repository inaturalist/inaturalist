require 'rubygems'
require 'trollop'

opts = Trollop::options do
    banner <<-EOS
Delete duplicate listed taxa

Usage:
  rails runner tools/remove_duplicate_listed_taxa.rb

Options:
EOS
  opt :test, "Don't actually touch the db", :short => "-t", :type => :boolean
end

OPTS = opts

destroyed_count = 0
scope = ListedTaxon.
  select("min(id) AS id, max(id) AS max_id, list_id, taxon_id, count(*) AS count").
  group("list_id, taxon_id").
  having("count(*) > 1").scoped
scope.each do |lt|
  puts "min: #{lt.id}, max: #{lt.max_id}, taxon: #{lt.taxon_id}, count: #{lt.count}"
  ListedTaxon.all(:conditions => "list_id = #{lt.list_id} AND taxon_id = #{lt.taxon_id} AND id > #{lt.id} AND id <= #{lt.max_id}").each do |dlt| 
    puts "destroying #{dlt}"
    lt.skip_sync_with_parent = true
    lt.skip_update_cache_columns = true
    lt.merge(dlt) unless OPTS[:test]
    destroyed_count += 1
  end
end
puts "Destroyed #{destroyed_count} duplicate listed taxa"
