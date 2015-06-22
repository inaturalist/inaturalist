class Hash
  def force_utf8
    Hash[
      self.map do |k, v|
        if v.is_a?(Hash) || v.is_a?(Array)
          [ k, v.force_utf8 ]
        elsif v.is_a?(Array)
          [ k, v.force_utf8 ]
        elsif (v.respond_to?(:to_utf8))
          [ k, v.to_utf8 ]
        elsif (v.respond_to?(:encoding))
          v.force_encoding("UTF-8")
          [ k, v.encode("UTF-8") ]
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
      if v.is_a?(Hash) || v.is_a?(Array)
        v.force_utf8
      elsif (v.respond_to?(:to_utf8))
        v.to_utf8
      elsif (v.respond_to?(:encoding))
        v.force_encoding("UTF-8")
        v.encode("UTF-8")
      else
        v
      end
    end
  end
end
