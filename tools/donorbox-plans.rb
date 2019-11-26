start = Time.now
if !CONFIG.donorbox || !CONFIG.donorbox.email || !CONFIG.donorbox.key
  raise "Donorbox email an API key haven't been added to config"
end
donorbox_email = CONFIG.donorbox.email
donorbox_key = CONFIG.donorbox.key
page = 1
per_page = 100
debug = true
num_plans = 0
num_updated_users = 0
num_invalid_users = 0
while true
  url = "https://donorbox.org/api/v1/plans?page=#{page}&per_page=#{per_page}"
  puts url if debug
  response = RestClient.get( url, {
    "Authorization" => "Basic #{Base64.strict_encode64( "#{donorbox_email}:#{donorbox_key}" ).strip}",
    "User-Agent" => "iNaturalist/Donorbox"
  } )
  json = JSON.parse( response )
  break if json.size == 0
  json.each do |plan|
    num_plans += 1
    next unless donor = plan["donor"]
    puts "Donor #{donor["id"]}"
    unless user = User.find_by_email( donor["email"] )
      puts "\tNo user"
      next
    end
    if user.donorbox_plan_type == "monthly" && plan["type"] != "monthly"
      # If the user has an existing monthly plan and this *isn't* a monthly
      # plan, just ignore it. We want to record all donors, but it's most
      # important to record when a user is a monthly donor or not
      next
    end
    user.donorbox_donor_id = donor["id"],
    user.donorbox_plan_type = plan["type"],
    user.donorbox_plan_status = plan["status"],
    user.donorbox_plan_started_at = Date.parse( plan["started_at"] ) rescue nil
    if user.changed?
      if user.donorbox_plan_status_changed? && user.donorbox_plan_status != "active"
        user.prefers_monthly_supporter_badge = false
      end
      if user.save
        puts "\tUpdated #{user}"
        num_updated_users += 1
      else
        puts "\tFailed to update user: #{user.errors.full_messages.to_sentence}" 
        num_invalid_users += 1
      end
    end
  end
  page += 1
end
puts
puts "#{num_plans} donors, #{num_updated_users} users udpated, #{num_invalid_users} invalid users in #{Time.now - start}s"
puts
