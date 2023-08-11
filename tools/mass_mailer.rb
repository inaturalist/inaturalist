# frozen_string_literal: true

require "rubygems"
require "optimist"

@opts = Optimist.options do
  banner <<~HELP
    Send large quantities of email using a mailer method that only takes a user as an argument.

    Examples:
      # Mail all confirmed users the independence email
      bundle exec rails r tools/mass_mailer.rb independence --confirmed

      # Mail all Spanish locale users the independence email
      bundle exec rails r tools/mass_mailer.rb independence --locale es

      # Mail es and es-MX users the independence mailer (but not es-AR)
      bundle exec rails r tools/mass_mailer.rb independence --locales es es-MX

    Usage:
      bundle exec rails r tools/mass_mailer.rb <mailer_method> [options]

    where [options] are:
  HELP
  opt :debug, "Print debug statements", type: :boolean, short: "-d"
  opt :dry, "Dry run, don't send emails, just report", type: :boolean
  opt :users, "Comma-separated list of user logins or IDs to mail for testing", type: :string
  opt :english, "Only email en-* locale users"
  opt :non_english, "Only email NOT en-* locale users"
  opt :min_id, "Minimum user ID", type: :integer, default: 0
  opt :max_id, "Maximum user ID", type: :integer
  opt :num_processes, "Number of subprocesses to use", type: :integer, short: "-p", default: 4
  opt :confirmed, "Only mail confirmed email addresses", type: :boolean
  opt :unconfirmed, "Only mail unconfirmed email addresses", type: :boolean
  opt :skip_recent, "Skip users created in the last month", type: :boolean
  opt :locale, "Locale to filter users by. Matches sublocales, so `es` will match `es-MX`", type: :string
  opt :locales, "Exact locales to filter users by (not wildcard matches)", type: :strings
  opt :skip_sendgrid_validation, "Skip Sendgrid email validation", type: :boolean
  opt :include_risky, "Send to addresses Sendgrid considers Risky", type: :boolean
end

mailer_method = ARGV.shift

if mailer_method.blank?
  Optimist.die "You must specify a mailer method"
end

unless Emailer.method_defined?( mailer_method )
  Optimist.die "#{Emailer.name}##{mailer_method} is not defined"
end

if Emailer.instance_method( mailer_method ).arity != 1
  Optimist.die <<~ERROR
    #{Emailer.name}##{mailer_method} requires more than one argument. This
     script only works with mailer methods that accept a user as the only
     argument
  ERROR
end

if @opts.english && @opts.non_english
  Optimist.die "You can't email English and non-English locale users"
end

if @opts.english && @opts.non_english
  Optimist.die "You can't email English and non-English locale users"
end

if @opts.confirmed && @opts.unconfirmed
  Optimist.die "You can't email confirmed and unconfirmed users"
end

if @opts.locale && ( @opts.english || @opts.non_english )
  Optimist.die "You can't specify a locale as well as the English or non-English filters"
end

if @opts.locale && @opts.locales
  Optimist.die "You can't specify a locale and locales. Choose one."
end

def sendgrid_validation_verdict( email )
  errors = [
    Timeout::Error,
    RestClient::ServiceUnavailable,
    RestClient::TooManyRequests,
    RestClient::BadGateway
  ]
  response = begin
    try_and_try_again( errors, exponential_backoff: true, sleep: 3 ) do
      RestClient.post(
        "https://api.sendgrid.com/v3/validations/email",
        { email: email }.to_json,
        { "Authorization" => "Bearer #{CONFIG.sendgrid.validation_api_key}" }
      )
    end
  rescue *errors
    return "Failed"
  end
  json = JSON.parse( response )
  json["result"]["verdict"]
end

test_users = @opts.users.to_s.split( "," )
scope = User.default_scoped
if test_users.size.positive?
  test_user_ids = test_users.map do | identifier |
    if identifier.to_i.positive?
      identifier
    else
      User.find_by_login( identifier ).id
    end
  end
  scope = scope.where( id: test_user_ids )
else
  scope = scope.
    # where( "confirmed_at IS NULL" ).
    where( "suspended_at IS NULL" ).
    where( "(NOT spammer OR spammer IS NULL)" ).
    where( "email IS NOT NULL" )
  if @opts.confirmed
    scope = scope.where( "confirmed_at IS NOT NULL" )
  elsif @opts.unconfirmed
    scope = scope.where( "confirmed_at IS NULL" )
  end
  if @opts.skip_recent
    # Don't email users who signed up in the last month
    scope = scope.where( "users.created_at < ?", 1.month.ago )
  end
end

if @opts.english
  scope = scope.where( "locale LIKE 'en%'" )
elsif @opts.non_english
  scope = scope.where( "locale NOT LIKE 'en%'" )
elsif @opts.locale
  scope = scope.where( "locale LIKE ?", "#{@opts.locale}%" )
elsif @opts.locales
  scope = scope.where( "locale IN (?)", @opts.locales )
end

@start = Time.now
@emailed = 0
@failed = 0
@failures_by_user_id = {}
@sendgrid_risky = 0
@sendgrid_invalid = 0
@sendgrid_failed = 0
@sendgrid_valid = 0

num_processes = @opts.num_processes
min_id = @opts.min_id
max_id = @opts.max_id || scope.calculate( :maximum, :id ).to_i
offset = ( max_id - min_id ) / num_processes
debug = @opts.debug
dry = @opts.dry

if @opts.debug
  puts "Starting #{num_processes} processes, min_id: #{min_id}, max_id: #{max_id}, offset: #{offset}"
end

results = Parallel.map( 0...num_processes, in_processes: num_processes ) do | process_index |
  start = min_id + ( offset * process_index )
  limit = process_index == ( num_processes - 1 ) ? max_id : start + offset - 1
  # Process id limits
  scope = scope.where( "users.id BETWEEN ? AND ? AND users.id > ?", start, limit, min_id )
  process_emailed = 0
  process_failed = 0
  process_failures_by_user_id = {}
  sendgrid_risky = 0
  sendgrid_invalid = 0
  sendgrid_failed = 0
  sendgrid_valid = 0
  if debug
    puts "Query: #{scope.to_sql}"
  end
  scope.script_find_each( label: "[Proc #{process_index}]" ) do | recipient |
    if recipient.email.size.zero?
      puts "[DEBUG] Email is blank" if debug
      next
    end

    if recipient.email_suppressed_in_group?(
      [
        EmailSuppression::BLOCKS,
        EmailSuppression::BOUNCES,
        EmailSuppression::INVALID_EMAILS
      ]
    )
      puts "[DEBUG] Suppression exists" if debug
      next
    end

    # Perform some pre-checks on the email address

    # If there's something there but it doesn't look like an email address
    unless Devise.email_regexp.match( recipient.email )
      puts "[DEBUG] invalid email: #{recipient.email}" if debug
      next
    end

    # This checks banned domains
    if ( CONFIG.banned_emails || [] ).detect {| suffix | recipient.email =~ /#{suffix}$/ }
      puts "[DEBUG] banned email suffix" if debug
      next
    end

    unless @opts.skip_sendgrid_validation
      verdict = sendgrid_validation_verdict( recipient.email )
      case verdict
      when "Valid"
        sendgrid_valid += 1
      when "Invalid"
        sendgrid_invalid += 1
      when "Risky"
        sendgrid_risky += 1
      else
        sendgrid_failed += 1
      end
      acceptable_verdits = %w(Valid)
      acceptable_verdits << "Risky" if @opts.include_risky
      unless acceptable_verdits.include?( verdict )
        puts "[DEBUG] Sendgrid validation failed for #{recipient.email}: #{verdict}" if debug
        next
      end
    end

    puts "[DEBUG] Emailing recipient: #{recipient}" if debug

    begin
      Emailer.send( mailer_method, recipient ).deliver_now unless dry
      process_emailed += 1
    rescue StandardError => e
      if debug
        puts "Caught error: #{e}"
      end
      process_failed += 1
      process_failures_by_user_id[recipient.id] = e
    end
  end
  puts "Proc #{process_index} (#{start} - #{limit}, min_id: #{min_id}) finished, " \
    "#{process_emailed} emailed, #{process_failed} failed"
  {
    process_index: process_index,
    emailed: process_emailed,
    failed: process_failed,
    failures_by_user_id: process_failures_by_user_id,
    sendgrid_risky: sendgrid_risky,
    sendgrid_invalid: sendgrid_invalid,
    sendgrid_failed: sendgrid_failed,
    sendgrid_valid: sendgrid_valid,
    start: start,
    limit: limit,
    min_id: min_id
  }
end

puts
puts "Process summary:"
results.each do | result |
  puts "Proc #{result[:process_index]} (#{result[:start]} - #{result[:limit]}, min_id: #{result[:min_id]}) finished, " \
    "#{result[:emailed]} emailed, #{result[:failed]} failed"
  @emailed += result[:emailed]
  @failed += result[:failed]
  @sendgrid_risky += result[:sendgrid_risky]
  @sendgrid_invalid += result[:sendgrid_invalid]
  @sendgrid_failed += result[:sendgrid_failed]
  @sendgrid_valid += result[:sendgrid_valid]
  @failures_by_user_id = @failures_by_user_id.merge( result[:failures_by_user_id] )
end

puts
puts "#{@emailed} users emailed, #{@failed} failed in #{Time.now - @start}s"
puts "Sendgrid validation: #{@sendgrid_valid} valid, #{@sendgrid_risky} risky, #{@sendgrid_invalid} invalid, " \
  "#{@sendgrid_failed} failed"
unless @failures_by_user_id.blank?
  puts "Failure user IDs: #{@failures_by_user_id.keys.join( ', ' )}"
  puts "First 5 failures:"
  @failures_by_user_id.to_a[0..5].each do | _user_id, error |
    puts error
    puts
  end
end
puts
