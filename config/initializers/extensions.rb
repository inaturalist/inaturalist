class Hash
  def force_utf8
    Hash[
      self.map do |k, v|
        # NaN doesn't work with JSON, so make them nil
        v = nil if v.is_a?(Float) && v.nan?
        if v.is_a?(Hash) || v.is_a?(Array)
          [ k, v.force_utf8 ]
        elsif v.is_a?(Array)
          [ k, v.force_utf8 ]
        elsif (v.respond_to?(:to_utf8))
          [ k, v.to_utf8 ]
        elsif (v.respond_to?(:encoding))
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
      if v.is_a?(Hash) || v.is_a?(Array)
        v.force_utf8
      elsif (v.respond_to?(:to_utf8))
        v.to_utf8
      elsif (v.respond_to?(:encoding))
        v.force_encoding("UTF-8")
        # remove any invalid characters
        v.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
      else
        v
      end
    end
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