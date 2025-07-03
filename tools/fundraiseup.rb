# frozen_string_literal: true

require "rubygems"
require "optimist"

opts = Optimist.options do
  banner <<~BANNER
    Sync FundraiseUp users with iNat User and UserParent records

    Usage:

      rails runner tools/fundraiseup.rb

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
  RestClient::InternalServerError
]

total_verified_users = 0
new_verified_users = 0
new_verified_user_parents = 0
failed_users = 0
failed_parents = 0
supporters = {}

last_record_id = nil
per_page = 100

loop do
  url = "https://api.fundraiseup.com/v1/supporters?limit=#{per_page}"
  if last_record_id
    url += "&starting_after=#{last_record_id}"
  end
  puts url if opts.debug
  response = try_and_try_again( potential_errors, exponential_backoff: true, sleep: 3 ) do
    RestClient.get( url, {
      "Authorization" => "Bearer #{CONFIG.fundraiseup.test_token}",
      "User-Agent" => "iNaturalist/FundraiseUp"
    } )
  end
  json = JSON.parse( response )
  break if json.empty?
  break if json["data"].empty?

  has_more = json["has_more"]
  json.each do | supporter |
    next if supporters[supporter["id"]]
    if opts.supporter_id && opts.supporter_id != supporter["id"]
      next
    end
    if opts.email && supporter["email"] !~ /#{opts.email}/i
      next
    end

    supporters[supporter["id"]] = true
    puts "Supporter #{supporter['id']}"
    if opts.debug
      puts supporter
    end
    if ( user = User.find_by_email( supporter["email"] ) )
      puts "\tSupporter: #{!user.fundraiseup_supporter_id.blank?}" if opts.debug
      if user.fundraiseup_supporter_id.blank?
        if opts.dry || user.update( fundraiseup_supporter_id: supporter["id"] )
          puts "\tMarked #{user} as a supporter"
          new_verified_users += 1
        else
          puts "Failed to mark #{user} as a supporter: #{user.errors.full_messages.to_sentence}"
          failed_users += 1
        end
      end
      total_verified_users += 1
    end
    user_parent = UserParent.find_by_email( supporter["email"] )
    # Sometimes the parent enters the same email on Donorobox as they use for
    # their iNat account, but they entered a different email address when
    # filling out the UserParent form. This should make sure that if we know the
    # user is a donor AND they filled out the UserParent form, their child
    # should be approved, even if they used a different email address on the
    # UserParent form
    user_parent ||= user.parentages.where( "fundraiseup_supporter_id IS NULL" ).first if user
    next unless user_parent

    puts "\tUserParent Supporter: #{!user_parent.fundraiseup_supporter_id.blank?}" if opts.debug
    next unless user_parent.fundraiseup_supporter_id.blank?

    begin
      if opts.dry || user_parent.update( fundraiseup_supporter_id: supporter["id"] )
        puts "\tMarked #{user_parent} as a supporter"
        new_verified_user_parents += 1
      else
        puts "Failed to mark #{user_parent} as a supporter: #{user.errors.full_messages.to_sentence}"
        failed_parents += 1
      end
    rescue OpenSSL::SSL::SSLError, Net::ReadTimeout => e
      # Mail failed to send
      puts "Failed to mark #{user_parent} as a supporter: mail delivery failed (#{e})"
      failed_parents += 1
    end
  end
  break if has_more == false

  sleep( 1 )
end

puts
puts "#{supporters.size} supporters, #{total_verified_users} supporter users, " \
  "#{new_verified_users} new supporters users, #{new_verified_user_parents} new " \
  "supporters parents, #{failed_users} failed users, #{failed_parents} failed " \
  "parents in #{Time.now - start}s"
puts

task_logger&.end
