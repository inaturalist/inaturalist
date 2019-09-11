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
  site = options[:site] || Site.default
  providers = ( options[:site] && options[:site].ratatosk_name_providers ) || [ "col", "eol" ]
  if !providers.blank?
    if providers.include?(src.to_s.downcase)
      Ratatosk::Ratatosk.new(:name_providers => [src])
    else
      Ratatosk::Ratatosk.new( name_providers: providers )
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
    logins = scan(/(\B)@([\\\w][\\\w\\\-_]*)/).flatten
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
# well as normalize Latin accented characters while leaving non-Latin
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

# Helper to perform a long running task, catch an exception, and try again
# after sleeping for a while
def try_and_try_again( exceptions, options = { } )
  exceptions = [exceptions].flatten
  tries = options.delete( :tries ) || 3
  sleep_for = options.delete( :sleep ) || 60
  logger = options[:logger] || Rails.logger
  begin
    yield
  rescue *exceptions => e
    if ( tries -= 1 ).zero?
      raise e
    else
      logger.debug "Caught #{e.class}, sleeping for #{sleep_for} s before trying again..."
      sleep( sleep_for )
      retry
    end
  end
end

def get_i18n_keys_in_rb
  all_keys = []
  scanner_proc = Proc.new do |f|
    # Ignore non-files
    next unless File.file?( f )
    # Ignore images and php scripts
    next unless f =~ /\.(rb|erb|haml)$/
    # Ignore an existing translations file
    # next if paths_to_ignore.include?( f )
    contents = IO.read( f )
    results = contents.scan(/(I18n\.)?t[\(\s]*([\:"'])([A-z_\.\d\?\!]+)/i)
    unless results.empty?
      all_keys += results.map{ |r| r[2].chomp(".") }
    end
  end
  Dir.glob(Rails.root.join("app/controllers/**/*")).each(&scanner_proc)
  Dir.glob(Rails.root.join("app/views/**/*")).each(&scanner_proc)
  Dir.glob(Rails.root.join("app/models/**/*")).each(&scanner_proc)
  Dir.glob(Rails.root.join("app/helpers/**/*")).each(&scanner_proc)
  all_keys
end

# Returns all keys in dot notation, e.g. views.observations.show.some_text
def get_i18n_keys_in_js( options = {} )
  paths_to_ignore = ["app/assets/javascripts/i18n/translations.js"]
  # various keys from models, or from JS dynamic calls
  all_keys = [
    "added!",
    "amphibians",
    "animals",
    "arachnids",
    "asc",
    "birds",
    "black",
    "blue",
    "brown",
    "browse",
    "casual",
    "checklist",
    "colors",
    "copyright",
    "data_quality",
    "date.formats.month_day_year",
    "date_added",
    "date_format.month",
    "date_picker",
    "date_updated",
    "desc",
    "edit_license",
    "endemic",
    "exporting",
    "find",
    "find",
    "flowering_phenology",
    "frequency",
    "fungi",
    "green",
    "grey",
    "imperiled",
    "input_taxon",
    "insect_life_stage",
    "insects",
    "introduced",
    "kml_file_size_error",
    "lexicons",
    "lexicons",
    "loading",
    "mammals",
    "maps",
    "maptype_for_places",
    "misidentifications",
    "mollusks",
    "momentjs",
    "native",
    "none",
    "number_selected",
    "observation_date",
    "orange",
    "output_taxon",
    "pink",
    "place_geo.geo_planet_place_types",
    "places_name",
    "places_name",
    "plants",
    "preview",
    "protozoans",
    "purple",
    "random",
    "ranks",
    "ray_finned_fishes",
    "red",
    "reload_timed_out",
    "reptiles",
    "research",
    "rg_observations",
    "saving",
    "something_went_wrong_adding",
    "status_globally",
    "status_in_place",
    "supporting",
    "taxon_drop",
    "taxon_merge",
    "taxon_split",
    "taxon_stage",
    "taxon_swap",
    "unknown",
    "view_more",
    "views.observations.export.taking_a_while",
    "views.taxa.show.frequency",
    "white",
    "vulnerable",
    "yellow",
    "you_are_setting_this_project_to_aggregate"
  ]
  %w(
    all_rank_added_to_the_database
    all_taxa
    controlled_term_labels
    establishment
  ).each do |key|
    all_keys += I18n.t( key ).map{|k,v| "#{key}.#{k}" }
  end
  all_keys += ControlledTerm.attributes.map{|a|
    a.values.map{|v| "add_#{a.label.parameterize.underscore}_#{v.label.underscore}_annotation" }
  }.flatten
  # look for other keys in all javascript files
  scanner_proc = Proc.new do |f|
    # Ignore non-files
    next unless File.file?( f )
    # Ignore images and php scripts
    next if f =~ /\.(gif|png|php)$/
    # Ignore generated webpack outputs
    next if f =~ /\-webpack.js$/
    # Ignore an existing translations file
    next if paths_to_ignore.include?( f )
    contents = IO.read( f )
    results = contents.scan(/(I18n|shared).t\(\s*(["'])(.*?)\2/i)
    unless results.empty?
      all_keys += results.map{ |r| r[2].chomp(".") }.select{|k| k =~ /^[A-z]/ }
    end
  end
  Dir.glob(Rails.root.join("app/assets/javascripts/**/*")).each(&scanner_proc)
  Dir.glob(Rails.root.join("app/webpack/**/*")).each(&scanner_proc)

  # look for keys in angular expressions in all templates
  Dir.glob(Rails.root.join("app/views/**/*")).each do |f|
    next unless File.file?( f )
    next if f =~ /\.(gif|png|php)$/
    next if paths_to_ignore.include?( f )
    contents = IO.read( f )
    results = contents.scan(/\{\{.*?(I18n|shared).t\( ?(.)(.*?)\2.*?\}\}/i)
    unless results.empty?
      all_keys += results.map{ |r| r[2].chomp(".") }.select{|k| k =~ /^[A-z]/ }
    end
  end

  # remnant from a dynamic JS call for colors
  all_keys.delete("lts[i].valu")
  all_keys
end
