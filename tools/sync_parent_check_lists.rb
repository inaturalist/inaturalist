CheckList.joins(:place).
  where("places.parent_id IS NOT NULL").
  order("places.place_type DESC").find_each do |cl|
  if cl.listed_taxa.count == 0
    puts "\tskipping #{cl.id}"
  else
    cl.sync_with_parent(force: true, skip_sync_with_parent:true, force_update_observation_associates: true)
  end
end
