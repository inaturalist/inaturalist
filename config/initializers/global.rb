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

  # https://stackoverflow.com/a/19438403
  WHITNEY_CODEPOINTS = [
    32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50,
    51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69,
    70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88,
    89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105,
    106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120,
    121, 122, 123, 124, 125, 126, 160, 161, 162, 163, 165, 167, 168, 169, 170,
    171, 174, 175, 176, 177, 178, 179, 180, 182, 183, 184, 185, 186, 187, 188,
    189, 190, 191, 192, 193, 194, 195, 196, 197, 198, 199, 200, 201, 202, 203,
    204, 205, 206, 207, 208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 218,
    219, 220, 221, 222, 223, 224, 225, 226, 227, 228, 229, 230, 231, 232, 233,
    234, 235, 236, 237, 238, 239, 240, 241, 242, 243, 244, 245, 246, 247, 248,
    249, 250, 251, 252, 253, 254, 255, 256, 257, 258, 259, 260, 261, 262, 263,
    266, 267, 268, 269, 270, 271, 272, 273, 274, 275, 276, 277, 278, 279, 280,
    281, 282, 283, 286, 287, 288, 289, 290, 291, 294, 295, 298, 299, 300, 301,
    302, 303, 304, 305, 310, 311, 313, 314, 315, 316, 317, 318, 319, 320, 321,
    322, 323, 324, 325, 326, 327, 328, 332, 333, 334, 335, 336, 337, 338, 339,
    340, 341, 342, 343, 344, 345, 346, 347, 350, 351, 352, 353, 354, 355, 356,
    357, 362, 363, 364, 365, 366, 367, 368, 369, 370, 371, 372, 373, 374, 375,
    376, 377, 378, 379, 380, 381, 382, 402, 506, 507, 508, 509, 510, 511, 536,
    537, 601, 710, 711, 728, 729, 730, 731, 732, 733, 806, 3647, 7808, 7809,
    7810, 7811, 7812, 7813, 7922, 7923, 8194, 8195, 8196, 8197, 8199, 8201,
    8202, 8211, 8212, 8216, 8217, 8218, 8220, 8221, 8222, 8224, 8225, 8226,
    8230, 8249, 8250, 8260, 8304, 8308, 8309, 8310, 8311, 8312, 8313, 8320,
    8321, 8322, 8323, 8324, 8325, 8326, 8327, 8328, 8329, 8353, 8358, 8360,
    8361, 8362, 8364, 8369, 8471, 8480, 8482, 8531, 8532, 8533, 8534, 8535,
    8536, 8537, 8538, 8539, 8540, 8541, 8542, 8722, 64_256, 64_257, 64_258, 64_259,
    64_260, 9, 13, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46,
    47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65,
    66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84,
    85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102,
    103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117,
    118, 119, 120, 121, 122, 123, 124, 125, 126, 128, 129, 130, 131, 132, 133,
    134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148,
    149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159, 160, 161, 162, 163,
    164, 165, 166, 167, 168, 169, 170, 171, 172, 174, 175, 177, 180, 187, 188,
    190, 191, 192, 193, 196, 199, 200, 201, 202, 203, 204, 205, 206, 207, 208,
    209, 210, 211, 212, 213, 214, 216, 217, 218, 219, 220, 221, 222, 223, 224,
    225, 226, 227, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239, 241,
    242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255, 32,
    33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51,
    52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70,
    71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89,
    90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106,
    107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121,
    122, 123, 124, 125, 126, 160, 161, 162, 163, 165, 167, 168, 169, 170, 171,
    174, 175, 176, 177, 178, 179, 180, 182, 183, 184, 185, 186, 187, 188, 189,
    190, 191, 192, 193, 194, 195, 196, 197, 198, 199, 200, 201, 202, 203, 204,
    205, 206, 207, 208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 218, 219,
    220, 221, 222, 223, 224, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234,
    235, 236, 237, 238, 239, 240, 241, 242, 243, 244, 245, 246, 247, 248, 249,
    250, 251, 252, 253, 254, 255, 256, 257, 258, 259, 260, 261, 262, 263, 266,
    267, 268, 269, 270, 271, 272, 273, 274, 275, 276, 277, 278, 279, 280, 281,
    282, 283, 286, 287, 288, 289, 290, 291, 294, 295, 298, 299, 300, 301, 302,
    303, 304, 305, 310, 311, 313, 314, 315, 316, 317, 318, 319, 320, 321, 322,
    323, 324, 325, 326, 327, 328, 332, 333, 334, 335, 336, 337, 338, 339, 340,
    341, 342, 343, 344, 345, 346, 347, 350, 351, 352, 353, 354, 355, 356, 357,
    362, 363, 364, 365, 366, 367, 368, 369, 370, 371, 372, 373, 374, 375, 376,
    377, 378, 379, 380, 381, 382, 402, 506, 507, 508, 509, 510, 511, 536, 537,
    601, 710, 711, 728, 729, 730, 731, 732, 733, 806, 3647, 7808, 7809, 7810,
    7811, 7812, 7813, 7922, 7923, 8194, 8195, 8196, 8197, 8199, 8201, 8202,
    8211, 8212, 8216, 8217, 8218, 8220, 8221, 8222, 8224, 8225, 8226, 8230,
    8249, 8250, 8260, 8304, 8308, 8309, 8310, 8311, 8312, 8313, 8320, 8321,
    8322, 8323, 8324, 8325, 8326, 8327, 8328, 8329, 8353, 8358, 8360, 8361,
    8362, 8364, 8369, 8471, 8480, 8482, 8531, 8532, 8533, 8534, 8535, 8536,
    8537, 8538, 8539, 8540, 8541, 8542, 8722, 64_256, 64_257, 64_258, 64_259,
    64_260
  ].freeze

  def whitney_support?
    chars.detect {| c | !WHITNEY_CODEPOINTS.include?( c.codepoints[0] ) }.blank?
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
