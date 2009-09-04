class ActiveRecord::Base
  named_scope :conditions, lambda {|*args| {:conditions => args}}
end