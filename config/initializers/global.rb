# frozen_string_literal: true

def start_log_timer( name = nil )
  @log_timer = Time.now
  @log_timer_name = name || caller( 2 ).first.split( "/" ).last
  Rails.logger.debug "\n\n[DEBUG] *********** Started log timer from #{@log_timer_name} at #{@log_timer} ***********"
end

def end_log_timer
  Rails.logger.debug "[DEBUG] *********** Finished log timer from " \
    "#{@log_timer_name} (#{Time.now - @log_timer}s) ***********\n\n"
  @log_timer = nil
  @log_timer_name = nil
end
alias stop_log_timer end_log_timer

def log_timer( name = nil )
  start_log_timer( name )
  r = yield
  end_log_timer
  r
end

class Object
  def try_methods( *methods )
    methods.each do | method |
      if respond_to?( method ) && !send( method ).blank?
        return send( method )
      end
    end
    nil
  end
end

# Call a proc or lambda that returns something array-like, but if doing so
# raises an exception, use the block to partition the args into smaller chunks
# of work in the form of arrays of arrays of args to call the callable with.
# This method recursively calls itself, breaking the work down into smaller and
# smaller chunks until it can do the work without raising the specified
# exceptions. This is intended to be used with burly elasticsearch queries that
# will raise exceptions when the result set is too large. options takes an
# optional exception_checker that is yet another callable to check whether the
# exception should trigger partitioning. If that returns false, the exception
# will be raised.
def call_and_rescue_with_partitioner( callable, args, exceptions, options = {}, &partitioner )
  exceptions = [exceptions].flatten
  options[:depth] ||= 0
  debug = options[:debug]
  args = [args].flatten
  begin
    callable.call( *args )
  rescue *exceptions => e
    if options[:exception_checker] && !options[:exception_checker].call( e )
      raise e
    end

    arg_partitions = partitioner.call( args )
    # If parallel operation was requested, we want to limit the amount of
    # parallel workers so they don't scale out infinitely. If you request 4
    # parallel workers with a binary partitioner, then the max depth for
    # parallelization should be 2 (first recursion should generate 2 workers,
    # next should generate a total of 4). Beyond that we should run subsequent
    # recursions in sequence. This will save a bit of time regardless, but will
    # work best when the partitions are relatively even. For the kinds of
    # imbalanced data we generally work with, the heavier partitions will end
    # up running in sequence in a single worker. Kind of wish we could do this
    # with promises instead...
    max_parallel_depth = ( options[:parallel].to_f / arg_partitions.size ).floor
    puts "max_parallel_depth: #{max_parallel_depth}" if debug
    puts "options[:depth]: #{options[:depth]}" if debug
    if options[:parallel] && options[:depth].to_i < max_parallel_depth
      puts "processing partitions in parallel for args: #{args}" if debug
      Parallel.map( arg_partitions, in_threads: arg_partitions.size ) do | partitioned_args |
        call_and_rescue_with_partitioner(
          callable,
          partitioned_args,
          exceptions,
          options.merge( depth: options[:depth] + 1 ),
          &partitioner
        )
      end.flatten
    else
      puts "processing partitions in sequence for args: #{args}" if debug
      arg_partitions.map do | partitioned_args |
        call_and_rescue_with_partitioner(
          callable,
          partitioned_args,
          exceptions,
          options.merge( depth: options[:depth] + 1 ),
          &partitioner
        )
      end.flatten
    end
  end
end

def ratatosk( options = {} )
  src = options[:src]
  site = options[:site] || Site.default
  providers = site&.ratatosk_name_providers || ["col"]
  if providers.blank?
    Ratatosk
  elsif providers.include?( src.to_s.downcase )
    Ratatosk::Ratatosk.new( name_providers: [src] )
  else
    Ratatosk::Ratatosk.new( name_providers: providers )
  end
end

class String
  def sanitize_encoding
    begin
      blank?
    rescue ArgumentError => e
      raise e unless e.message =~ /invalid byte sequence in UTF-8/

      return encode( "utf-8", "iso-8859-1" )
    end
    self
  end

  # rubocop:disable Naming/PredicateName
  def is_ja?
    !!( self =~ /[ぁ-ゖァ-ヺー一-龯々]/ )
  end
  # rubocop:enable Naming/PredicateName

  def mentioned_users
    logins = scan( /(\B)@([\\\w][\\\w\-_]*)/ ).flatten
    return [] if logins.blank?

    User.where( login: logins ).limit( 500 )
  end

  def context_of_pattern( pattern, context_length = 100 )
    fix = ".{0,#{context_length}}"
    return unless ( matches = match( /(#{fix})(#{pattern})(#{fix})/ ) )

    parts = []
    parts << "..." if matches[1].length == context_length
    parts << matches[1]
    parts << matches[2]
    parts << matches[3]
    parts << "..." if matches[3].length == context_length
    parts.join
  end

  def all_latin_chars?
    chars.detect {| c | c.bytes.size > 1 }.blank?
  end

  def non_latin_chars?
    !all_latin_chars?
  end
end

# Restrict some queries to characters, numbers, and simple punctuation, as
# well as normalize Latin accented characters while leaving non-Latin
# characters alone.
# http://www.ruby-doc.org/core-2.0.0/Regexp.html#label-Character+Properties
# http://stackoverflow.com/a/10306827/720268
def sanitize_query( query )
  return query if query.blank?

  # rubocop:disable Layout/LineLength
  query.tr(
    "ÀÁÂÃÄÅàáâãäåĀāĂăĄąÇçĆćĈĉĊċČčÐðĎďĐđÈÉÊËèéêëĒēĔĕĖėĘęĚěĜĝĞğĠġĢģĤĥĦħÌÍÎÏìíîïĨĩĪīĬĭĮįİıĴĵĶķĸĹĺĻļĽľĿŀŁłÑñŃńŅņŇňŉŊŋÒÓÔÕÖØòóôõöøŌōŎŏŐőŔŕŖŗŘřŚśŜŝŞşŠšſŢţŤťŦŧÙÚÛÜùúûüŨũŪūŬŭŮůŰűŲųŴŵÝýÿŶŷŸŹźŻżŽž",
    "AAAAAAaaaaaaAaAaAaCcCcCcCcCcDdDdDdEEEEeeeeEeEeEeEeEeGgGgGgGgHhHhIIIIiiiiIiIiIiIiIiJjKkkLlLlLlLlLlNnNnNnNnnNnOOOOOOooooooOoOoOoRrRrRrSsSsSsSssTtTtTtUUUUuuuuUuUuUuUuUuUuWwYyyYyYZzZzZz"
  ).gsub( /[^\p{L}\s.'\-\d]+/, "" ).gsub( /-/, "\\-" )
  # rubocop:enable Layout/LineLength
end

def private_page_cache_path( path )
  # remove absolute release path for Capistrano. Yes, this assumes you're
  # using Capistrano. Please suggest a better way.
  root = Rails.root.to_s.sub( /releases#{File::SEPARATOR}\d+/, "current" )
  File.join( root, "tmp", "page_cache", path )
end

# Haversine distance calc, adapted from http://www.movable-type.co.uk/scripts/latlong.html
def lat_lon_distance_in_meters( lat1, lon1, lat2, lon2 )
  earth_radius = 6_370_997 # m
  degrees_per_radian = 57.2958
  degrees_lat = ( lat2 - lat1 ) / degrees_per_radian
  degrees_lon = ( lon2 - lon1 ) / degrees_per_radian
  lat1 /= degrees_per_radian
  lat2 /= degrees_per_radian
  a = ( Math.sin( degrees_lat / 2 ) * Math.sin( degrees_lat / 2 ) ) +
    ( Math.sin( degrees_lon / 2 ) * Math.sin( degrees_lon / 2 ) * Math.cos( lat1 ) * Math.cos( lat2 ) )
  c = 2 * Math.atan2( Math.sqrt( a ), Math.sqrt( 1 - a ) )
  earth_radius * c
end

# rubocop:disable Lint/SuppressedException
# IDK why we're supressing this exception. If someone else wants to embrace
# the risk, go for it. ~~~kueda 20230810
def fetch_head( url, follow_redirects: true )
  begin
    uri = URI( url )
    http = Net::HTTP.new( uri.host, uri.port )
    http.use_ssl = ( url =~ /^https/ )
    rsp = http.head( uri.request_uri )
    if rsp.is_a?( Net::HTTPRedirection ) && follow_redirects
      return fetch_head( rsp["location"], false )
    end

    return rsp
  rescue StandardError
  end
  nil
end
# rubocop:enable Lint/SuppressedException

# Helper to perform a long running task, catch an exception, and try again
# after sleeping for a while
def try_and_try_again( exceptions, options = {} )
  exceptions = [exceptions].flatten
  try = 0
  tries = options.delete( :tries ) || 3
  base_sleep_duration = options.delete( :sleep ) || 60
  logger = options[:logger] || Rails.logger
  begin
    try += 1
    yield
  rescue *exceptions => e
    # raise e if ( tries -= 1 ).zero?
    raise e if try > tries

    logger.debug "Caught #{e.class}, sleeping for #{base_sleep_duration} s before trying again..."
    sleep_duration = base_sleep_duration
    if options[:exponential_backoff]
      sleep_duration = base_sleep_duration**try
    end
    sleep( sleep_duration )
    retry
  end
end
