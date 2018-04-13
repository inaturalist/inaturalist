class Hash
  def force_utf8
    Hash[
      self.map do |k, v|
        # NaN doesn't work with JSON, so make them nil
        v = nil if v.is_a?(Float) && v.nan?
        if v.is_a?(Hash) # || v.instance_of?(Array)
          [ k, v.force_utf8 ]
        elsif v.instance_of?(Array)
          [ k, v.force_utf8 ]
        elsif v.respond_to?(:to_utf8)
          [ k, v.to_utf8 ]
        elsif v.respond_to?(:encoding)
          v.force_encoding("UTF-8")
          # remove any invalid characters
          [ k, v.encode("UTF-8", invalid: :replace, undef: :replace, replace: "") ]
        else
          [ k, v ]
        end
      end
    ]
  end
end

class Array
  def force_utf8
    self.map do |v|
      # NaN doesn't work with JSON, so make them nil
      v = nil if v.is_a?(Float) && v.nan?
      if v.is_a?(Hash) || v.instance_of?(Array)
        v.force_utf8
      elsif v.respond_to?(:to_utf8)
        v.to_utf8
      elsif v.respond_to?(:encoding)
        v.force_encoding("UTF-8")
        # remove any invalid characters
        v.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
      else
        v
      end
    end
  end

  def median
    sorted = dup.sort
    len = sorted.length
    (sorted[(len - 1) / 2] + sorted[len / 2]) / 2.0
  end
end

class OpenStruct
  def self.new_recursive(hash)
    struct = new(hash)
    struct.to_h.each do |k,v|
      if v.is_a?(Hash)
        struct.send("#{ k }=", new_recursive(v))
      end
    end
    struct
  end
end

class String
  def with_fixed_https
    self.gsub(/http:\/\/(www|static)\.inaturalist\.org/, "https://\\1.inaturalist.org").
      gsub(/http:\/\/(farm[1-9])\.static/, "https://\\1.static").
      gsub(/http:\/\/upload\.wikimedia/, "https://upload.wikimedia").
      gsub(/http:\/\/media\.eol\.org/, "https://media.eol.org")
  end
end
