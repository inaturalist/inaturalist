# frozen_string_literal: true

require "rubygems"
require "optimist"

opts = Optimist.options do
  banner <<~BANNER
    Sync donorbox users with iNat User and UserParent records

    Usage:

      rails runner tools/donorbox.rb

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
# debug = true
total_verified_users = 0
new_verified_users = 0
new_verified_user_parents = 0
failed_users = 0
failed_parents = 0
donors = {}
loop do
  url = "https://donorbox.org/api/v1/donors?page=#{page}&per_page=#{per_page}"
  puts url if opts.debug
  response = RestClient.get( url, {
    "Authorization" => "Basic #{Base64.strict_encode64( "#{donorbox_email}:#{donorbox_key}" ).strip}",
    "User-Agent" => "iNaturalist/Donorbox"
  } )
  json = JSON.parse( response )
  break if json.size.zero?

  json.each do | donor |
    next if donors[donor["id"]]
    if opts.donor_id && opts.donor_id.to_i != donor["id"].to_i
      next
    end
    if opts.email && donor["email"] !~ /#{opts.email}/i
      next
    end

    donors[donor["id"]] = true
    puts "Donor #{donor['id']}"
    if opts.debug
      puts donor
    end
    if ( user = User.find_by_email( donor["email"] ) )
      puts "\tDonor: #{user.donor?}" if opts.debug
      unless user.donor?
        if opts.dry || user.update( donorbox_donor_id: donor["id"] )
          puts "\tMarked #{user} as a donor"
          new_verified_users += 1
        else
          puts "Failed to mark #{user} as a donor: #{user.errors.full_messages.to_sentence}"
          failed_users += 1
        end
      end
      total_verified_users += 1
    end
    user_parent = UserParent.find_by_email( donor["email"] )
    # Sometimes the parent enters the same email on Donorobox as they use for
    # their iNat account, but they entered a different email address when
    # filling out the UserParent form. This should make sure that if we know the
    # user is a donor AND they filled out the UserParent form, their child
    # should be approved, even if they used a different email address on the
    # UserParent form
    user_parent ||= user.parentages.where( "donorbox_donor_id IS NULL" ).first if user
    next unless user_parent

    puts "\tUserParent Donor: #{user_parent.donor?}" if opts.debug
    next if user_parent.donor?

    begin
      if opts.dry || user_parent.update( donorbox_donor_id: donor["id"] )
        puts "\tMarked #{user_parent} as a donor"
        new_verified_user_parents += 1
      else
        puts "Failed to mark #{user_parent} as a donor: #{user.errors.full_messages.to_sentence}"
        failed_parents += 1
      end
    rescue OpenSSL::SSL::SSLError, Net::ReadTimeout => e
      # Mail failed to send
      puts "Failed to mark #{user_parent} as a donor: mail delivery failed (#{e})"
      failed_parents += 1
    end
  end
  page += 1
end
puts
puts "#{donors.size} donors, #{total_verified_users} donor users, " \
  "#{new_verified_users} new donor users, #{new_verified_user_parents} new " \
  "donor parents, #{failed_users} failed users, #{failed_parents} failed " \
  "parents in #{Time.now - start}s"
puts
