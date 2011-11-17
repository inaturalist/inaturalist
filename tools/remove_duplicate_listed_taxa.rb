destroyed_count = 0
ListedTaxon.all(
    :select => "min(id) AS id, max(id) AS max_id, list_id, taxon_id, count(*) AS count",
    :group => "list_id, taxon_id",
    :having => "count(*) > 1").each do |lt|
  puts "min: #{lt.id}, max: #{lt.max_id}, taxon: #{lt.taxon_id}, count: #{lt.count}"
  ListedTaxon.all(:conditions => "list_id = #{lt.list_id} AND taxon_id = #{lt.taxon_id} AND id > #{lt.id} AND id <= #{lt.max_id}").each do |dlt| 
    puts "destroying #{dlt}"
    dlt.destroy
    destroyed_count += 1
  end
end
puts "Destroyed #{destroyed_count} duplicate listed taxa"
