require "rubygems"
require "optimist"

opts = Optimist::options do
    banner <<-EOS
Sync donorbox user plans with iNat users. Primarily for letting us know when a
user is a Monthly Supporter.

Usage:

  rails runner tools/donorbox-plans.rb

where [options] are:
EOS
  opt :debug, "Print debug statements", type: :boolean, short: "-d"
  opt :dry, "Dry run, don't actually change anything", type: :boolean
  opt :email, "Filter results by Donorbox donor email", type: :string
  opt :donor_id, "Filter results by Donorbox donor ID", type: :string
end

start = Time.now
if !CONFIG.donorbox || !CONFIG.donorbox.email || !CONFIG.donorbox.key
  raise "Donorbox email an API key haven't been added to config"
end
donorbox_email = CONFIG.donorbox.email
donorbox_key = CONFIG.donorbox.key
page = 1
per_page = 100
num_plans = 0
num_updated_users = 0
num_invalid_users = 0
active_user_ids = []
while true
  url = "https://donorbox.org/api/v1/plans?page=#{page}&per_page=#{per_page}"
  puts url if opts.debug
  response = RestClient.get( url, {
    "Authorization" => "Basic #{Base64.strict_encode64( "#{donorbox_email}:#{donorbox_key}" ).strip}",
    "User-Agent" => "iNaturalist/Donorbox"
  } )
  json = JSON.parse( response )
  break if json.size == 0
  json.each do |plan|
    num_plans += 1
    next unless donor = plan["donor"]
    if opts.donor_id && opts.donor_id.to_i != donor["id"].to_i
      next
    end
    if opts.email && donor["email"] !~ /#{opts.email}/i
      next
    end
    puts "Donor #{donor["id"]}"
    if opts.debug
      puts plan
    end
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
    if active_user_ids.include?( user.id )
      # If we've already encountered this user in this sync and that user has an
      # active monthly plan, ignore all other plans. They might be cancelled,
      # and we don't want to register the user as having a cancelled plan on our
      # end
      next
    end
    active_user_ids << user.id
    user.donorbox_donor_id = donor["id"]
    user.donorbox_plan_type = plan["type"]
    user.donorbox_plan_status = plan["status"]
    user.donorbox_plan_started_at = Date.parse( plan["started_at"] ) rescue nil
    if user.changed?
      if user.donorbox_plan_status_changed? && user.donorbox_plan_status != "active"
        user.prefers_monthly_supporter_badge = false
      end
      user_updated = opts.dry || user.save
      if user_updated
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
