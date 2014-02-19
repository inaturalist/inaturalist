class String
  def yesish?
    %w(1 yes y true t).include?(self.downcase)
  end

  def noish?
    %w(0 no n false f).include?(self.downcase)
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
