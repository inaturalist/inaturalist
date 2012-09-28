def start_log_timer(name = nil)
  @log_timer = Time.now
  @log_timer_name = name || caller(2).first.split('/').last
  Rails.logger.debug "\n\n[DEBUG] *********** Started log timer from #{@log_timer_name} at #{@log_timer} ***********"
end

def end_log_timer
  Rails.logger.debug "[DEBUG] *********** Finished log timer from #{@log_timer_name} (#{Time.now - @log_timer}s) ***********\n\n"
  @log_timer, @log_timer_name = nil, nil
end

def log_timer(name = nil)
  start_log_timer(name)
  yield
  end_log_timer
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
  if INAT_CONFIG['ratatosk'] && INAT_CONFIG['ratatosk']['name_providers']
    if INAT_CONFIG['ratatosk']['name_providers'].include?(src.to_s.downcase)
      Ratatosk::Ratatosk.new(:name_providers => [src])
    else
      @@ratatosk ||= Ratatosk::Ratatosk.new(:name_providers => INAT_CONFIG['ratatosk']['name_providers'])
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
