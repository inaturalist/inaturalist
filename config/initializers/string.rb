class String
  def yesish?
    %w(1 yes y true t).include?(self.downcase)
  end

  def noish?
    %w(0 no n false f).include?(self.downcase)
  end
end
