# frozen_string_literal: true

require "rubygems"
require "optimist"

opts = Optimist.options do
  banner <<~BANNER
    Sync Virtuous user tags with iNaturalist users

    Usage:

      rails runner tools/virtuous_user_tag_sync.rb

    where [options] are:
  BANNER
  opt :dry, "Dry run, don't actually change anything", type: :boolean
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

potential_errors = [
  Timeout::Error,
  RestClient::ServiceUnavailable,
  RestClient::GatewayTimeout,
  RestClient::TooManyRequests,
  RestClient::InternalServerError
]

tag_users = UserVirtuousTag::POSSIBLE_TAGS.to_h {| k | [k, []] }
last_contact_id = nil

loop do
  conditions = [{
    parameter: "Tag",
    operator: "IsAnyOf",
    values: UserVirtuousTag::POSSIBLE_TAGS
  }]
  if last_contact_id
    conditions << {
      parameter: "Contact Id",
      operator: "GreaterThan",
      value: last_contact_id
    }
  end
  post_body = {
    groups: [{
      conditions: conditions
    }],
    sortBy: "Id",
    descending: "false"
  }
  url = "#{full_contact_endpoint}?take=1000"
  puts "Calling #{url} with:"
  pp post_body

  response = try_and_try_again( potential_errors, exponential_backoff: true, sleep: 3 ) do
    RestClient.post( url, post_body.to_json, {
      Authorization: "Bearer #{CONFIG.virtuous.token}",
      content_type: :json,
      accept: :json
    } )
  end
  break if response&.code != 200

  puts "Ratelimit remaining: #{response.headers[:x_ratelimit_remaining]}"
  puts

  response_body = JSON.parse( response.body )
  break if response_body["list"].empty?

  response_body["list"]&.each do | contact |
    contact_inaturalist_user_ids = []
    contact["contactIndividuals"]&.each do | individual |
      individual["contactMethods"]&.each do | contact_method |
        next unless contact_method["type"].downcase.include?( "email" )
        next unless contact_method["value"].include?( "@" )

        inaturalist_user = User.find_by_email( contact_method["value"].downcase )
        next unless inaturalist_user

        contact_inaturalist_user_ids << inaturalist_user.id
      end
    end

    contact["tags"].each do | tag |
      next unless tag_users[tag]

      tag_users[tag] += contact_inaturalist_user_ids
    end
    last_contact_id = contact["id"]
  end
end

user_tags_created = 0
tag_users.each do | tag, user_ids |
  user_ids.uniq.each do | user_id |
    next if UserVirtuousTag.where( user_id: user_id, virtuous_tag: tag ).exists?

    puts "Creating new UserVirtuousTag => { user_id: #{user_id}, virtuous_tag: #{tag} }"
    user_tags_created += 1
    next if opts.dry

    UserVirtuousTag.create( user_id: user_id, virtuous_tag: tag )
  end
end

user_tags_removed = 0
UserVirtuousTag.find_each do | uvt |
  next if tag_users[uvt.virtuous_tag]&.include?( uvt.user_id )

  puts "Deleting vestigial UserVirtuousTag => { user_id: #{uvt.user_id}, virtuous_tag: #{uvt.virtuous_tag} }"
  user_tags_removed += 1
  next if opts.dry

  UserVirtuousTag.where( user_id: uvt.user_id, virtuous_tag: uvt.virtuous_tag ).delete_all
end

total_user_tags = tag_users.sum {| _k, v | v.size }
puts
puts "Total User Tags: #{total_user_tags}"
puts "User Tags Created: #{user_tags_created}"
puts "User Tags Removed: #{user_tags_removed}"
puts "Completed In: #{( Time.now - start_time ).round( 2 )}s"
puts

task_logger&.end
