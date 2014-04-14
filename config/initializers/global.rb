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
      @@ratatosk ||= Ratatosk::Ratatosk.new(:name_providers => CONFIG.ratatosk.name_providers)
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
end

# Restrict sphinx queries to charactersm, numbers, and simple punctuation
# http://www.ruby-doc.org/core-2.0.0/Regexp.html#label-Character+Properties
def sanitize_sphinx_query(q)
  q.gsub(/[^\p{L}\s\.\'\-\d]+/, '').gsub(/\-/, '\-')
end

def private_page_cache_path(path)
  File.join(Rails.root, 'tmp', 'page_cache', path)
end
