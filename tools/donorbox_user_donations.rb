# frozen_string_literal: true

require "rubygems"
require "optimist"

opts = Optimist.options do
  banner <<~BANNER
    Sync donorbox donations with UserDonation records

    Usage:

      rails runner tools/donorbox_user_donations.rb

    where [options] are:
  BANNER
  opt :debug, "Print debug statements", type: :boolean, short: "-d"
end

if !CONFIG.donorbox || !CONFIG.donorbox.email || !CONFIG.donorbox.key
  raise "Donorbox email an API key haven't been added to config"
end

donorbox_email = CONFIG.donorbox.email
donorbox_key = CONFIG.donorbox.key
donation_lookup_start_time = 1.day.ago.strftime( "%Y-%m-%d" )
page = 1
per_page = 100
loop do
  url = "https://donorbox.org/api/v1/donations?page=#{page}&per_page=#{per_page}&date_from=#{donation_lookup_start_time}"
  puts url if opts.debug
  response = RestClient.get( url, {
    "Authorization" => "Basic #{Base64.strict_encode64( "#{donorbox_email}:#{donorbox_key}" ).strip}",
    "User-Agent" => "iNaturalist/Donorbox"
  } )
  json = JSON.parse( response )
  break if json.size.zero?

  json.each do | donation |
    next unless donation["donor"]
    next if donation["donor"]["email"].blank?

    user = User.find_by_email( donation["donor"]["email"] )
    next unless user
    next if UserDonation.where( user: user, donated_at: donation["donation_date"] ).exists?

    if opts.debug
      puts "Adding donation for `#{user.login}` on `#{donation['donation_date']}`"
    end
    UserDonation.create( user: user, donated_at: donation["donation_date"] )
  end
  if opts.debug
    ratelimit_remaining = response.headers[:x_ratelimit_remaining]
    puts "Ratelimit remaining: #{ratelimit_remaining}"
  end
  sleep( 1 )
  page += 1
end
