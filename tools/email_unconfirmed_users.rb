# frozen_string_literal: true

require "rubygems"
require "optimist"

@opts = Optimist.options do
  banner <<~HELP
    Email unconfirmed users asking them to confirm

    where [options] are:
  HELP
  opt :debug, "Print debug statements", type: :boolean, short: "-d"
  opt :dry, "Dry run, don't make changes, just report", type: :boolean
  opt :users, "Comma-separated list of user logins or IDs to mail for testing", type: :string
  opt :english, "Only email en-* locale users"
  opt :non_english, "Only email NOT en-* locale users"
end

test_users = @opts.users.to_s.split( "," )
scope = if test_users.size.positive?
  test_user_ids = test_users.map do | identifier |
    if identifier.to_i.positive?
      identifier
    else
      User.find_by_login( identifier ).id
    end
  end
  User.where( id: test_user_ids )
else
  User.
    where( "confirmed_at IS NULL" ).
    where( "(NOT spammer OR spammer IS NULL)" ).
    where( "email IS NOT NULL" )
end

if @opts.english
  scope = scope.where( "locale LIKE 'en%'" )
elsif @opts.non_english
  scope = scope.where( "locale NOT LIKE 'en%'" )
end

@start = Time.now
@emailed = 0
@failed = 0
@failures_by_user_id = {}

scope.script_find_each do | recipient |
  next if recipient.email.size.zero?
  next if recipient.email_suppressed_in_group?(
    [
      EmailSuppression::BLOCKS,
      EmailSuppression::BOUNCES,
      EmailSuppression::INVALID_EMAILS
    ]
  )
  next if @opts.users.blank? && recipient.confirmed?

  puts "[DEBUG] Emailing recipient: #{recipient}" if @opts.debug

  begin
    Emailer.email_confirmation_reminder( recipient ).deliver_now unless @opts.dry
    @emailed += 1
  rescue => e
    @failed += 1
    @failures_by_user_id[recipient.id] = e
  end
end

puts
puts "#{@emailed} users emailed, #{@failed} failed in #{Time.now - @start}s"
unless @failures_by_user_id.blank?
  puts "Failure user IDs: #{@failures_by_user_id.keys.join( ', ' )}"
  puts "First 5 failures:"
  @failures_by_user_id.to_a[0..5].each do | _user_id, error |
    puts error
    puts
  end
end
puts
