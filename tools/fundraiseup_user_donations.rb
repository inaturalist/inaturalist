# frozen_string_literal: true

require "rubygems"
require "optimist"

opts = Optimist.options do
  banner <<~BANNER
    Sync FundraiseUp donations with UserDonation records

    Usage:

      rails runner tools/fundraiseup_user_donations.rb

    where [options] are:
  BANNER
  opt :debug, "Print debug statements", type: :boolean, short: "-d"
  opt :log_task_name, "Log with the specified task name", type: :string
end

if opts.log_task_name
  task_logger = TaskLogger.new( opts.log_task_name, nil, "sync" )
end

task_logger&.start

if !CONFIG.fundraiseup || !CONFIG.fundraiseup.token
  raise "FundraiseUp API key hasn't been added to config"
end

potential_errors = [
  Timeout::Error,
  RestClient::ServiceUnavailable,
  RestClient::GatewayTimeout,
  RestClient::TooManyRequests,
  RestClient::InternalServerError
]

donation_lookup_start_time = 1.day.ago
last_record_id = nil
per_page = 100

loop do
  url = "https://api.fundraiseup.com/v1/donations?limit=#{per_page}"
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
  json["data"].each do | donation |
    last_record_id = donation["id"]
    donation_time = Time.parse( donation["created_at"] )
    if donation_time < donation_lookup_start_time
      has_more = false
      break
    end
    next unless donation["supporter"]
    next if donation["supporter"]["email"].blank?
    next unless donation["succeeded_at"]

    user = User.find_by_email( donation["supporter"]["email"] )
    next unless user
    next if UserDonation.where( user: user, donated_at: donation["created_at"] ).exists?

    if opts.debug
      puts "Adding donation for `#{user.login}` on `#{donation['created_at']}`"
    end
    UserDonation.create( user: user, donated_at: donation["created_at"] )
  end
  break if has_more == false

  sleep( 1 )
end

task_logger&.end
