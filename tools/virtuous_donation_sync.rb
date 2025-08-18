# frozen_string_literal: true

require "rubygems"
require "optimist"

opts = Optimist.options do
  banner <<~BANNER
    Sync Virtuous donations

    Usage:

      rails runner tools/virtuous_donation_sync.rb

    where [options] are:
  BANNER
  opt :dry, "Dry run, don't actually change anything", type: :boolean
  opt :after_date, "Sync donations made after this date/time", type: :string
  opt :log_task_name, "Log with the specified task name", type: :string
end

if !CONFIG.virtuous || !CONFIG.virtuous.token
  raise "Virtuous token hasn't been added to config"
end

if opts.log_task_name
  task_logger = TaskLogger.new( opts.log_task_name, nil, "sync" )
end

task_logger&.start
start_time = Time.now

full_contact_endpoint = "https://api.virtuoussoftware.com/api/Contact/Query/FullContact"
gift_query_endpoint = "https://api.virtuoussoftware.com/api/Gift/Query"

potential_errors = [
  Timeout::Error,
  RestClient::ServiceUnavailable,
  RestClient::GatewayTimeout,
  RestClient::TooManyRequests,
  RestClient::InternalServerError,
  RestClient::BadGateway
]

total_verified_users = 0
new_verified_users = 0
new_verified_user_parents = 0
failed_users = 0
failed_parents = 0
user_donations = 0
donors = {}

last_gift_id = nil

loop do
  conditions = []
  if opts.after_date
    conditions << {
      parameter: "Gift Date",
      operator: "GreaterThan",
      value: opts.after_date
    }
  end
  if last_gift_id
    conditions << {
      parameter: "Gift Id",
      operator: "GreaterThan",
      value: last_gift_id
    }
  end
  post_body = {
    groups: [{
      conditions: conditions
    }],
    sortBy: "Id",
    descending: "false"
  }
  url = "#{gift_query_endpoint}?take=1000"
  puts "Calling #{url} with:"
  pp post_body

  # fetch a batch of gifts
  response = try_and_try_again( potential_errors, exponential_backoff: true, sleep: 3 ) do
    RestClient.post( url, post_body.to_json, {
      Authorization: "Bearer #{CONFIG.virtuous.token}",
      content_type: :json,
      accept: :json
    } )
  end
  break if response&.code != 200

  puts "Ratelimit remaining: #{response.headers[:x_ratelimit_remaining]}"
  response_body = JSON.parse( response.body )
  break if response_body["list"].empty?

  puts "Total results: #{response_body['total']}"
  puts "Run time: #{( Time.now - start_time ).round( 2 )}s"
  puts

  # fetch the contacts for the batch of gifts
  contact_ids = response_body["list"].map {| gift | gift["contactId"] }
  contacts_post_body = {
    groups: [],
    sortBy: "Id",
    descending: "false"
  }
  contact_ids.each do | contact_id |
    contacts_post_body[:groups] << {
      conditions: [{
        parameter: "Contact Id",
        operator: "Is",
        value: contact_id
      }]
    }
  end
  contacts_url = "#{full_contact_endpoint}?take=1000"
  puts "Calling #{contacts_url} with long post body"

  contacts_response = try_and_try_again( potential_errors, exponential_backoff: true, sleep: 3 ) do
    RestClient.post( contacts_url, contacts_post_body.to_json, {
      Authorization: "Bearer #{CONFIG.virtuous.token}",
      content_type: :json,
      accept: :json
    } )
  end
  next unless contacts_response&.code == 200

  puts "Ratelimit remaining: #{contacts_response.headers[:x_ratelimit_remaining]}"
  puts

  contact_inaturalist_users = {}
  contact_user_parents = {}
  contacts_response_body = JSON.parse( contacts_response.body )
  contacts_response_body["list"]&.each do | contact |
    contact_id = contact["id"]
    contact["contactIndividuals"]&.each do | individual |
      individual["contactMethods"]&.each do | contact_method |
        next unless contact_method["type"].downcase.include?( "email" )
        next unless contact_method["value"].include?( "@" )

        if ( inaturalist_user = User.find_by_email( contact_method["value"].downcase ) )
          contact_inaturalist_users[contact_id] ||= []
          contact_inaturalist_users[contact_id] << inaturalist_user
          if inaturalist_user.parentages.length.positive?
            contact_user_parents[contact_id] ||= []
            contact_user_parents[contact_id] += inaturalist_user.parentages
          end
        end
        user_parents = UserParent.where( email: contact_method["value"].downcase )
        if user_parents.length.positive?
          contact_user_parents[contact_id] ||= []
          contact_user_parents[contact_id] += user_parents
        end
      end
    end
  end

  response_body["list"].each do | gift |
    contact_id = gift["contactId"]
    donors[contact_id] = true
    contact_inaturalist_users[contact_id]&.uniq&.each do | user |
      puts "\tDonor: #{user.donor?}" if opts.debug
      if user.virtuous_donor_contact_id.blank?
        if opts.dry || user.update( virtuous_donor_contact_id: contact_id )
          puts "\tMarked #{user} as a donor"
          new_verified_users += 1
        else
          puts "Failed to mark #{user} as a donor: #{user.errors.full_messages.to_sentence}"
          failed_users += 1
        end
      end
      total_verified_users += 1

      gift_date = Date.strptime( gift["giftDate"], "%m/%e/%Y" )
      next if UserDonation.where( user: user ).where( "DATE(donated_at) = ?", gift_date ).exists?

      puts "\tAdding donation for #{user} on #{gift['giftDate']}"
      unless opts.dry
        UserDonation.create( user: user, donated_at: gift_date )
      end
      user_donations += 1
    end

    contact_user_parents[contact_id]&.uniq&.each do | user_parent |
      next unless user_parent.virtuous_donor_contact_id.blank?

      begin
        if opts.dry || user_parent.update( virtuous_donor_contact_id: contact_id )
          puts "\tMarked #{user_parent} as a donor"
          new_verified_user_parents += 1
        else
          puts "Failed to mark #{user_parent} as a donor: #{user_parent.errors.full_messages.to_sentence}"
          failed_parents += 1
        end
      rescue OpenSSL::SSL::SSLError, Net::ReadTimeout => e
        # Mail failed to send
        puts "Failed to mark #{user_parent} as a donor: mail delivery failed (#{e})"
        failed_parents += 1
      end
    end

    last_gift_id = gift["id"]
  end
end

puts
puts "#{donors.size} donors, #{total_verified_users} donor users, " \
  "#{new_verified_users} new donor users, #{new_verified_user_parents} new " \
  "donor parents, #{failed_users} failed users, #{failed_parents} failed " \
  "parents, #{user_donations} user donations in " \
  "#{( Time.now - start_time ).round( 2 )}s"
puts

task_logger&.end
