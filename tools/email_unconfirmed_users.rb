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
  opt :min_id, "Minimum user ID, mostly for testing and restarging a stopped process", type: :integer, default: 0
  opt :max_id, "Maximum user ID, mostly for testing", type: :integer
  opt :num_processes, "Number of subprocesses to use", type: :integer, short: "-p", default: 4
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

num_processes = @opts.num_processes
min_id = @opts.min_id
max_id = @opts.max_id || scope.calculate( :maximum, :id ).to_i
offset = max_id / num_processes
debug = @opts.debug
dry = @opts.dry
custom_users_requested = @opts.users.blank?

if @opts.debug
  puts "Starting #{num_processes} processes, min_id: #{min_id}, max_id: #{max_id}, offset: #{offset}"
end

results = Parallel.map( 0...num_processes, in_processes: num_processes ) do | process_index |
  start = offset * process_index
  limit = process_index == ( num_processes - 1 ) ? max_id : start + offset - 1
  # Process id limits
  scope = scope.where( "users.id BETWEEN ? AND ? AND users.id > ?", start, limit, min_id )
  # Don't email users who signed up in the last month
  scope = scope.where( "users.created_at < ?", 1.month.ago )
  process_emailed = 0
  process_failed = 0
  process_failures_by_user_id = {}
  if debug
    puts "Query: #{scope.to_sql}"
  end
  scope.script_find_each( label: "[Proc #{process_index}]" ) do | recipient |
    next if recipient.email.size.zero?
    next if recipient.email_suppressed_in_group?(
      [
        EmailSuppression::BLOCKS,
        EmailSuppression::BOUNCES,
        EmailSuppression::INVALID_EMAILS
      ]
    )
    next if !custom_users_requested && recipient.confirmed?

    puts "[DEBUG] Emailing recipient: #{recipient}" if debug

    begin
      Emailer.email_confirmation_reminder( recipient ).deliver_now unless dry
      process_emailed += 1
    rescue StandardError => e
      if debug
        puts "Caught error: #{e}"
      end
      process_failed += 1
      process_failures_by_user_id[recipient.id] = e
    end
  end
  { emailed: process_emailed, failed: process_failed, failures_by_user_id: process_failures_by_user_id }
end

results.each do | result |
  @emailed += result[:emailed]
  @failed += result[:failed]
  @failures_by_user_id = @failures_by_user_id.merge( result[:failures_by_user_id] )
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
