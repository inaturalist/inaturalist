# http://stackoverflow.com/a/20117850
require 'bigdecimal'
module ToNumeric
  def to_numeric
    num = BigDecimal(to_s == "" ? 0 : to_s)
    if num.frac == 0
      num.to_i
    else
      num.to_f
    end
  end
end
class Integer
  include ToNumeric
end
class String
  include ToNumeric
end
class NilClass
  include ToNumeric
end
