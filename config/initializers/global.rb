#encoding: utf-8
def start_log_timer(name = nil)
  @log_timer = Time.now
  @log_timer_name = name || caller(2).first.split('/').last
  Rails.logger.debug "\n\n[DEBUG] *********** Started log timer from #{@log_timer_name} at #{@log_timer} ***********"
end

def end_log_timer
  Rails.logger.debug "[DEBUG] *********** Finished log timer from #{@log_timer_name} (#{Time.now - @log_timer}s) ***********\n\n"
  @log_timer, @log_timer_name = nil, nil
end
alias :stop_log_timer :end_log_timer

def log_timer(name = nil)
  start_log_timer(name)
  r = yield
  end_log_timer
  r
end

class Object
  def try_methods(*methods)
    methods.each do |method|
      if respond_to?(method) && !send(method).blank?
        return send(method)
      end
    end
    nil
  end
end

def ratatosk(options = {})
  src = options[:src]
  if CONFIG.ratatosk && CONFIG.ratatosk.name_providers
    if CONFIG.ratatosk.name_providers.include?(src.to_s.downcase)
      Ratatosk::Ratatosk.new(:name_providers => [src])
    else
      @ratatosk ||= Ratatosk::Ratatosk.new(:name_providers => CONFIG.ratatosk.name_providers)
    end
  else
    Ratatosk
  end
end

class String
  def sanitize_encoding
    begin
      blank?
    rescue ArgumentError => e
      raise e unless e.message =~ /invalid byte sequence in UTF-8/
      return encode('utf-8', 'iso-8859-1')
    end
    self
  end

  def is_ja?
    !! (self =~ /[ぁ-ゖァ-ヺー一-龯々]/)
  end

  def mentioned_users
    logins = scan(/(^|\s|>)@([\\\w][\\\w\\\-_]*)/).flatten
    return [ ] if logins.blank?
    User.where(login: logins).limit(500)
  end

  def context_of_pattern(pattern, context_length = 100)
    fix = ".{0,#{ context_length }}"
    if matches = match(/(#{ fix })(#{ pattern })(#{ fix })/)
      parts = [ ]
      parts << "..." if (matches[1].length == context_length)
      parts << matches[1]
      parts << matches[2]
      parts << matches[3]
      parts << "..." if (matches[3].length == context_length)
      parts.join
    end
  end

end

# Restrict some queries to characters, numbers, and simple punctuation, as
# well as normalize Latin accented characters while leaving non-latic
# characters alone.
# http://www.ruby-doc.org/core-2.0.0/Regexp.html#label-Character+Properties
# http://stackoverflow.com/a/10306827/720268
def sanitize_query(q)
  return q if q.blank?
  q.tr( 
    "ÀÁÂÃÄÅàáâãäåĀāĂăĄąÇçĆćĈĉĊċČčÐðĎďĐđÈÉÊËèéêëĒēĔĕĖėĘęĚěĜĝĞğĠġĢģĤĥĦħÌÍÎÏìíîïĨĩĪīĬĭĮįİıĴĵĶķĸĹĺĻļĽľĿŀŁłÑñŃńŅņŇňŉŊŋÒÓÔÕÖØòóôõöøŌōŎŏŐőŔŕŖŗŘřŚśŜŝŞşŠšſŢţŤťŦŧÙÚÛÜùúûüŨũŪūŬŭŮůŰűŲųŴŵÝýÿŶŷŸŹźŻżŽž", 
    "AAAAAAaaaaaaAaAaAaCcCcCcCcCcDdDdDdEEEEeeeeEeEeEeEeEeGgGgGgGgHhHhIIIIiiiiIiIiIiIiIiJjKkkLlLlLlLlLlNnNnNnNnnNnOOOOOOooooooOoOoOoRrRrRrSsSsSsSssTtTtTtUUUUuuuuUuUuUuUuUuUuWwYyyYyYZzZzZz"
  ).gsub(/[^\p{L}\s\.\'\-\d]+/, '').gsub(/\-/, '\-')
end

def private_page_cache_path(path)
  # remove absolute release path for Capistrano. Yes, this assumes you're
  # using Capistrano. Please suggest a better way.
  root = Rails.root.to_s.sub(/releases#{File::SEPARATOR}\d+/, 'current')
  File.join(root, 'tmp', 'page_cache', path)
end

# Haversine distance calc, adapted from http://www.movable-type.co.uk/scripts/latlong.html
def lat_lon_distance_in_meters(lat1, lon1, lat2, lon2)
  earthRadius = 6370997 # m 
  degreesPerRadian = 57.2958
  dLat = (lat2-lat1) / degreesPerRadian
  dLon = (lon2-lon1) / degreesPerRadian
  lat1 = lat1 / degreesPerRadian
  lat2 = lat2 / degreesPerRadian
  a = Math.sin(dLat/2) * Math.sin(dLat/2) +
      Math.sin(dLon/2) * Math.sin(dLon/2) * Math.cos(lat1) * Math.cos(lat2)
  c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))
  d = earthRadius * c  
  d
end

def fetch_head(url)
  begin
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (url =~ /^https/)
    return http.head(uri.request_uri)
  rescue
  end
  nil
end
