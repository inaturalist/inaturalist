require "rubygems"
require "optimist"

opts = Optimist::options do
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
error_count = 0
mutable_columns = ListedTaxon.column_names - %w(id created_at updated_at)
scope = ListedTaxon.
  select("min(id) AS id, max(id) AS max_id, list_id, taxon_id, count(*) AS count").
  group("list_id, taxon_id").
  having("count(*) > 1")
scope.each do |lt|
  puts "min: #{lt.id}, max: #{lt.max_id}, taxon: #{lt.taxon_id}, count: #{lt.count}"
  candidates = ListedTaxon.where("list_id = #{lt.list_id} AND taxon_id = #{lt.taxon_id}")
  keeper = candidates.detect{|c| c.id == lt.id}
  candidates.select{|c| c.id != lt.id}.each do |reject| 
    puts "destroying #{reject}"
    mutable_columns.each do |column|
      keeper.send("#{column}=", reject.send(column)) if keeper.send(column).blank?
    end
    reject.destroy unless OPTS[:test]
    destroyed_count += 1
  end
  keeper.skip_sync_with_parent = true
  keeper.skip_update_cache_columns = true
  unless OPTS[:test]
    unless keeper.save
      puts "failed to save #{keeper}: #{keeper.errors.full_messages.to_sentence}"
      error_count += 1
    end
  end
end
puts "Destroyed #{destroyed_count} duplicate listed taxa, #{error_count} keepers failed to save"
