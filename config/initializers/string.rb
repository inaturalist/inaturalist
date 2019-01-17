class String
  def yesish?
    %w(1 yes y true t).include?(self.downcase)
  end

  def noish?
    %w(0 no n false f).include?(self.downcase)
  end

  def utf_safe
    encode('UTF-8')
  rescue Encoding::UndefinedConversionError
    I18n.t(:encoding_error, :default => "encoding error")
  end
end

class NilClass
  def yesish?
    false
  end

  def noish?
    false
  end
end

class TrueClass
  def yesish?
    true
  end

  def noish?
    false
  end
end

class FalseClass
  def yesish?
    false
  end

  def noish?
    true
  end
end

class Integer
  def yesish?
    self == 1
  end

  def noish?
    self == 0
  end
end
