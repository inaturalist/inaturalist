# frozen_string_literal: true

require "rubygems"
require "optimist"

opts = Optimist.options do
  banner <<~BANNER
    Sync FundraiseUp user plans with iNat users. Primarily for letting us know
    when a user is a Monthly Supporter.
    Usage:
      rails runner tools/fundraiseup_plans.rb
    where [options] are:
  BANNER
  opt :debug, "Print debug statements", type: :boolean, short: "-d"
  opt :dry, "Dry run, don't actually change anything", type: :boolean
  opt :email, "Filter results by FundraiseUp supporter email", type: :string
  opt :supporter_id, "Filter results by FundraiseUp supporter ID", type: :string
  opt :log_task_name, "Log with the specified task name", type: :string
end

if opts.log_task_name
  task_logger = TaskLogger.new( opts.log_task_name, nil, "sync" )
end

task_logger&.start

start = Time.now
if !CONFIG.fundraiseup || !CONFIG.fundraiseup.token
  raise "FundraiseUp API key hasn't been added to config"
end

potential_errors = [
  Timeout::Error,
  RestClient::ServiceUnavailable,
  RestClient::GatewayTimeout,
  RestClient::TooManyRequests,
  RestClient::InternalServerError,
  RestClient::BadGateway
]

num_plans = 0
num_updated_users = 0
num_invalid_users = 0
active_user_ids = []
changes = {}

last_record_id = nil
per_page = 100

puts
puts "## Retrieving data from FundraiseUp..."
puts
loop do
  url = "https://api.fundraiseup.com/v1/recurring_plans?limit=#{per_page}"
  if last_record_id
    url += "&starting_after=#{last_record_id}"
  end
  puts url if opts.debug
  response = try_and_try_again( potential_errors, exponential_backoff: true, sleep: 3 ) do
    RestClient.get( url, {
      "Authorization" => "Bearer #{CONFIG.fundraiseup.token}",
      "User-Agent" => "iNaturalist/FundraiseUp"
    } )
  end
  json = JSON.parse( response )
  break if json.empty?
  break if json["data"].empty?

  has_more = json["has_more"]
  json["data"].each do | plan |
    last_record_id = plan["id"]
    num_plans += 1
    next unless ( supporter = plan["supporter"] )
    if opts.supporter && opts.supporter != supporter["id"]
      next
    end
    if opts.email && supporter["email"] !~ /#{opts.email}/i
      next
    end

    puts "Supporter #{supporter['id']}"
    if opts.debug
      puts plan
    end
    unless ( user = User.find_by_email( supporter["email"] ) )
      puts "\tNo user"
      next
    end

    # Ensure fundraiseup_plan_started_at is the start date of the earliest
    # monthly plan, even if that plan is currently cancelled
    monthly_fundraiseup_plan_started_at = begin
      ( plan["frequency"] == "monthly" ) ? Date.parse( plan["created_at"] ) : nil
    rescue StandardError
      puts "\tFailed to parse plan created_at from #{plan['created_at']}"
      nil
    end
    min_fundraiseup_plan_started_at = [
      monthly_fundraiseup_plan_started_at,
      user.fundraiseup_plan_started_at,
      changes.dig( user.id, :fundraiseup_plan_started_at )
    ].compact.min
    if min_fundraiseup_plan_started_at &&
        user.fundraiseup_plan_started_at &&
        min_fundraiseup_plan_started_at < user.fundraiseup_plan_started_at
      puts "\tUpdating fundraiseup_plan_started_at to the start date of an earlier monthly plan" if opts.debug
      changes[user.id] ||= {}
      changes[user.id][:fundraiseup_plan_started_at] = min_fundraiseup_plan_started_at
    end

    if user.fundraiseup_plan_frequency == "monthly" && plan["frequency"] != "monthly"
      # If the user has an existing monthly plan and this *isn't* a monthly
      # plan, just ignore it. We want to record all supporters, but it's most
      # important to record when a user is a monthly supporters or not
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

    unless ["failed", "canceled"].include?( plan["status"] )
      active_user_ids << user.id
    end
    user.fundraiseup_plan_frequency = plan["frequency"]
    user.fundraiseup_plan_status = plan["status"]
    user.fundraiseup_plan_started_at = monthly_fundraiseup_plan_started_at

    # If we've already encountered a plan, we only want to replace it if this
    # plan is active
    puts "\tExisting change queued: #{changes[user.id]}" if opts.debug
    puts "\tPlan status: #{plan['status']}" if opts.debug
    unless !changes.dig( user.id, :fundraiseup_plan_frequency ) || plan["status"] == "active"
      next
    end

    changes[user.id] = {
      fundraiseup_plan_frequency: user.fundraiseup_plan_frequency,
      fundraiseup_plan_status: user.fundraiseup_plan_status,
      fundraiseup_plan_started_at: min_fundraiseup_plan_started_at
    }
    if opts.debug
      puts "\tAdded/replaced changes for #{user}: #{changes[user.id]}"
    end
  end
  break if has_more == false

  sleep( 1 )
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
puts "#{num_plans} supporters, #{num_updated_users} users udpated, " \
  "#{num_invalid_users} invalid users in #{Time.now - start}s"
puts

task_logger&.end
