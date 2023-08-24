# frozen_string_literal: true

require "rubygems"
require "optimist"

opts = Optimist.options do
  banner <<~BANNER
    Sync donorbox user plans with iNat users. Primarily for letting us know when a
    user is a Monthly Supporter.

    Usage:

      rails runner tools/donorbox-plans.rb

    where [options] are:
  BANNER
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
changes = {}

puts
puts "## Retrieving data from donorbox..."
puts
loop do
  url = "https://donorbox.org/api/v1/plans?page=#{page}&per_page=#{per_page}"
  puts url if opts.debug
  response = RestClient.get( url, {
    "Authorization" => "Basic #{Base64.strict_encode64( "#{donorbox_email}:#{donorbox_key}" ).strip}",
    "User-Agent" => "iNaturalist/Donorbox"
  } )
  json = JSON.parse( response )
  break if json.size.zero?

  json.each do | plan |
    num_plans += 1
    next unless ( donor = plan["donor"] )
    if opts.donor_id && opts.donor_id.to_i != donor["id"].to_i
      next
    end
    if opts.email && donor["email"] !~ /#{opts.email}/i
      next
    end

    puts "Donor #{donor['id']}"
    if opts.debug
      puts plan
    end
    unless ( user = User.find_by_email( donor["email"] ) )
      puts "\tNo user"
      next
    end

    # Ensure donorbox_plan_started_at is the start date of the earliest
    # monthly plan, even if that plan is currently cancelled
    monthly_donorbox_plan_started_at = begin
      plan["type"] == "monthly" ? Date.parse( plan["started_at"] ) : nil
    rescue StandardError
      puts "\tFailed to parse donorbox_plan_started_at from #{plan['started_at']}"
      nil
    end
    min_donorbox_plan_started_at = [
      monthly_donorbox_plan_started_at,
      user.donorbox_plan_started_at,
      changes.dig( user.id, :donorbox_plan_started_at )
    ].compact.min
    if min_donorbox_plan_started_at &&
        user.donorbox_plan_started_at &&
        min_donorbox_plan_started_at < user.donorbox_plan_started_at
      puts "\tUpdating donorbox_plan_started_at to the start date of an earlier monthly plan" if opts.debug
      changes[user.id] ||= {}
      changes[user.id][:donorbox_plan_started_at] = min_donorbox_plan_started_at
    end

    if user.donorbox_plan_type == "monthly" && plan["type"] != "monthly"
      # If the user has an existing monthly plan and this *isn't* a monthly
      # plan, just ignore it. We want to record all donors, but it's most
      # important to record when a user is a monthly donor or not
      puts "\tUser already has a monthly plan and this plan isn't monthly. Skipping..." if opts.debug
      next
    end
    if active_user_ids.include?( user.id )
      # If we've already encountered this user in this sync and that user has an
      # active monthly plan, ignore all other plans. They might be cancelled,
      # and we don't want to register the user as having a cancelled plan on our
      # end
      puts "\tAlready encountered an active plan for this user. Skipping..." if opts.debug
      next
    end

    active_user_ids << user.id unless plan["status"] == "cancelled"
    user.donorbox_donor_id = donor["id"]
    user.donorbox_plan_type = plan["type"]
    user.donorbox_plan_status = plan["status"]
    user.donorbox_plan_started_at = monthly_donorbox_plan_started_at

    # If we've already encountered a plan, we only want to replace it if this
    # plan is active
    puts "\tExisting change queued: #{changes[user.id]}" if opts.debug
    puts "\tPlan status: #{plan['status']}" if opts.debug
    unless !changes.dig( user.id, :donorbox_donor_id ) || plan["status"] == "active"
      next
    end

    changes[user.id] = {
      donorbox_donor_id: user.donorbox_donor_id,
      donorbox_plan_type: user.donorbox_plan_type,
      donorbox_plan_status: user.donorbox_plan_status,
      donorbox_plan_started_at: min_donorbox_plan_started_at
    }
    if opts.debug
      puts "\tAdded/replaced changes for #{user}: #{changes[user.id]}"
    end
  end
  page += 1
end

puts
puts "## Applying changes to #{changes.size} users..."
puts
changes.each do | user_id, updates |
  unless ( user = User.find_by_id( user_id ) )
    puts "User #{user_id} no longer exists"
    next
  end
  puts user if opts.debug
  puts "\tAssigning changes: #{updates}" if opts.debug
  user.assign_attributes( updates )
  # If status changed to cancelled, remove the monthly supporter badge
  if user.donorbox_plan_status_changed? && user.donorbox_plan_status != "active"
    user.prefers_monthly_supporter_badge = false
  end
  user_updated = opts.dry || user.save
  applied_changes = opts.dry ? user.changes : user.saved_changes
  if applied_changes.blank?
    puts "\tNo changes to apply"
  elsif user_updated
    puts "\tUpdated #{user}: #{applied_changes}"
    num_updated_users += 1
  else
    puts "\tFailed to update user: #{user.errors.full_messages.to_sentence}"
    num_invalid_users += 1
  end
end
puts
puts "#{num_plans} donors, #{num_updated_users} users udpated, " \
  "#{num_invalid_users} invalid users in #{Time.now - start}s"
puts
